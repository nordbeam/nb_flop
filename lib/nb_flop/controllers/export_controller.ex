defmodule NbFlop.ExportController do
  @moduledoc """
  Controller for exporting table data.

  Add these routes to your router:

      scope "/nb-flop", NbFlop do
        post "/action", ActionController, :execute
        post "/bulk-action", ActionController, :execute_bulk
        get "/export", ExportController, :export
      end

  Or use the router macro:

      use NbFlop.Router

      nb_flop_routes()
  """

  import Plug.Conn

  def init(opts), do: opts
  def call(conn, _opts), do: conn

  alias NbFlop.Exporters.CSVExporter
  alias NbFlop.Export

  @doc """
  Exports table data in the requested format.

  Expects query params:
    * `token` - Signed table token
    * `export` - Export name (e.g., "csv")
    * `filters` - Optional current table filters (JSON encoded)
  """
  def export(conn, %{"token" => token, "export" => export_name} = params) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, export} <- find_export(table_module, export_name),
         :ok <- authorize_export(export, conn),
         {:ok, rows} <- load_all_rows(table_module, params) do
      send_export_response(conn, table_module, rows, export, params)
    else
      {:error, :invalid_table} ->
        send_json(conn, 400, %{error: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{error: "Token expired"})

      {:error, :export_not_found} ->
        send_json(conn, 404, %{error: "Export not found"})

      {:error, :unauthorized} ->
        send_json(conn, 403, %{error: "Not authorized to export"})

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  def export(conn, _params) do
    send_json(conn, 400, %{error: "Missing required parameters"})
  end

  # Private helpers

  defp find_export(table_module, export_name) do
    export_atom =
      if is_binary(export_name), do: String.to_existing_atom(export_name), else: export_name

    if function_exported?(table_module, :exports, 0) do
      case Enum.find(table_module.exports(), &(&1.name == export_atom)) do
        nil -> {:error, :export_not_found}
        export -> {:ok, export}
      end
    else
      {:error, :export_not_found}
    end
  rescue
    ArgumentError -> {:error, :export_not_found}
  end

  defp authorize_export(%Export{authorize: nil}, _conn), do: :ok

  defp authorize_export(%Export{authorize: authorize}, conn) do
    if authorize.(conn), do: :ok, else: {:error, :unauthorized}
  end

  defp load_all_rows(table_module, params) do
    repo = table_module.repo()
    resource = table_module.resource()
    filters = parse_filters(params)

    # Build Flop query without pagination to get all matching rows
    flop_params = %{filters: filters}

    case Flop.validate(flop_params, for: resource) do
      {:ok, flop} ->
        query = Flop.query(resource, flop)
        {:ok, repo.all(query)}

      {:error, _} ->
        {:ok, repo.all(resource)}
    end
  end

  defp parse_filters(%{"filters" => filters_json}) when is_binary(filters_json) do
    case Jason.decode(filters_json) do
      {:ok, filters} when is_list(filters) ->
        Enum.map(filters, fn f ->
          %{
            field: String.to_existing_atom(f["field"]),
            op: parse_op(f["op"]),
            value: f["value"]
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp parse_filters(_), do: []

  defp parse_op(op) when is_atom(op), do: op
  defp parse_op("=="), do: :==
  defp parse_op("!="), do: :!=
  defp parse_op("ilike"), do: :ilike
  defp parse_op(">"), do: :>
  defp parse_op(">="), do: :>=
  defp parse_op("<"), do: :<
  defp parse_op("<="), do: :<=
  defp parse_op("in"), do: :in
  defp parse_op(op), do: String.to_existing_atom(op)

  defp send_export_response(conn, table_module, rows, export, params) do
    case export.format do
      :csv ->
        send_csv_response(conn, table_module, rows, export, params)

      :excel ->
        # Excel export not implemented yet
        send_json(conn, 501, %{error: "Excel export not implemented"})

      :pdf ->
        # PDF export not implemented yet
        send_json(conn, 501, %{error: "PDF export not implemented"})

      _ ->
        send_json(conn, 400, %{error: "Unknown export format"})
    end
  end

  defp send_csv_response(conn, table_module, rows, export, _params) do
    filename = CSVExporter.generate_filename(table_module, export)
    csv_data = CSVExporter.generate(table_module, rows, export)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv_data)
    |> halt()
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
    |> halt()
  end
end
