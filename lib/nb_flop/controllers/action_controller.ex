defmodule NbFlop.ActionController do
  @moduledoc """
  Controller for executing table row actions.

  Add these routes to your router:

      scope "/nb-flop", NbFlop do
        post "/action", ActionController, :execute
        post "/bulk-action", ActionController, :execute_bulk
      end
  """

  use Phoenix.Controller, formats: [:json]

  import Plug.Conn

  @doc """
  Executes a single row action.

  Expects JSON body:
    * `token` - Signed action token
    * `action` - Action name
    * `id` - Row ID
  """
  def execute(conn, %{"token" => token, "action" => action_name, "id" => id}) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, action} <- find_action(table_module, action_name),
         :ok <- authorize_action(action, conn),
         {:ok, row} <- load_row(table_module, id),
         :ok <- check_not_disabled(action, row, conn),
         result <- execute_action(action, row) do
      send_json_response(conn, result, action)
    else
      {:error, :invalid_table} ->
        send_json(conn, 400, %{success: false, message: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{success: false, message: "Token expired"})

      {:error, :action_not_found} ->
        send_json(conn, 404, %{success: false, message: "Action not found"})

      {:error, :unauthorized} ->
        send_json(conn, 403, %{success: false, message: "Not authorized"})

      {:error, :not_found} ->
        send_json(conn, 404, %{success: false, message: "Record not found"})

      {:error, :disabled} ->
        send_json(conn, 422, %{success: false, message: "Action is disabled for this record"})

      {:error, reason} when is_binary(reason) ->
        send_json(conn, 422, %{success: false, message: reason})

      {:error, reason} ->
        send_json(conn, 500, %{success: false, message: inspect(reason)})
    end
  end

  def execute(conn, _params) do
    send_json(conn, 400, %{success: false, message: "Missing required parameters"})
  end

  @doc """
  Executes a bulk action on multiple rows.

  Expects JSON body:
    * `token` - Signed action token
    * `action` - Bulk action name
    * `selection` - Selection object with `mode` and `ids`
    * `filters` - Current table filters (for "all" mode)
  """
  def execute_bulk(
        conn,
        %{"token" => token, "action" => action_name, "selection" => selection} = params
      ) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, action} <- find_bulk_action(table_module, action_name),
         :ok <- authorize_bulk_action(action, conn),
         {:ok, rows} <- load_selected_rows(table_module, selection, params),
         :ok <- run_before_callback(action, rows),
         result <- execute_bulk_action(action, rows),
         :ok <- run_after_callback(action, rows) do
      case result do
        :ok ->
          send_json(conn, 200, %{success: true, count: length(rows)})

        {:ok, message} ->
          send_json(conn, 200, %{success: true, count: length(rows), message: message})

        {:error, reason} ->
          send_json(conn, 422, %{success: false, message: to_string(reason)})
      end
    else
      {:error, :invalid_table} ->
        send_json(conn, 400, %{success: false, message: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{success: false, message: "Token expired"})

      {:error, :action_not_found} ->
        send_json(conn, 404, %{success: false, message: "Bulk action not found"})

      {:error, :unauthorized} ->
        send_json(conn, 403, %{success: false, message: "Not authorized"})

      {:error, reason} when is_binary(reason) ->
        send_json(conn, 422, %{success: false, message: reason})

      {:error, reason} ->
        send_json(conn, 500, %{success: false, message: inspect(reason)})
    end
  end

  def execute_bulk(conn, _params) do
    send_json(conn, 400, %{success: false, message: "Missing required parameters"})
  end

  # Private helpers

  defp find_action(table_module, action_name) do
    action_atom =
      if is_binary(action_name), do: String.to_existing_atom(action_name), else: action_name

    case Enum.find(table_module.actions(), &(&1.name == action_atom)) do
      nil -> {:error, :action_not_found}
      action -> {:ok, action}
    end
  rescue
    ArgumentError -> {:error, :action_not_found}
  end

  defp find_bulk_action(table_module, action_name) do
    action_atom =
      if is_binary(action_name), do: String.to_existing_atom(action_name), else: action_name

    case Enum.find(table_module.bulk_actions(), &(&1.name == action_atom)) do
      nil -> {:error, :action_not_found}
      action -> {:ok, action}
    end
  rescue
    ArgumentError -> {:error, :action_not_found}
  end

  defp authorize_action(%NbFlop.Action{authorize: nil}, _conn), do: :ok

  defp authorize_action(%NbFlop.Action{authorize: authorize}, conn) do
    if authorize.(conn), do: :ok, else: {:error, :unauthorized}
  end

  defp authorize_bulk_action(%NbFlop.BulkAction{authorize: nil}, _conn), do: :ok

  defp authorize_bulk_action(%NbFlop.BulkAction{authorize: authorize}, conn) do
    if authorize.(conn), do: :ok, else: {:error, :unauthorized}
  end

  defp load_row(table_module, id) do
    repo = table_module.repo()
    resource = table_module.resource()

    case repo.get(resource, id) do
      nil -> {:error, :not_found}
      row -> {:ok, row}
    end
  end

  defp check_not_disabled(%NbFlop.Action{disabled: nil}, _row, _conn), do: :ok

  defp check_not_disabled(%NbFlop.Action{disabled: disabled}, row, conn) do
    result =
      case Function.info(disabled, :arity) do
        {:arity, 1} -> disabled.(row)
        {:arity, 2} -> disabled.(row, conn)
      end

    if result, do: {:error, :disabled}, else: :ok
  end

  defp execute_action(%NbFlop.Action{handle: nil, url: url}, row) when is_function(url) do
    # URL action - return the URL for frontend redirect
    {:redirect, url.(row)}
  end

  defp execute_action(%NbFlop.Action{handle: handle}, row) when is_function(handle) do
    handle.(row)
  end

  defp send_json_response(conn, {:redirect, url}, _action) do
    send_json(conn, 200, %{success: true, redirect: url})
  end

  defp send_json_response(conn, :ok, action) do
    message = action.success_message || "Action completed successfully"
    send_json(conn, 200, %{success: true, message: message})
  end

  defp send_json_response(conn, {:ok, message}, _action) when is_binary(message) do
    send_json(conn, 200, %{success: true, message: message})
  end

  # Handle {:ok, struct} when the second element is not a string (e.g., from Ecto operations)
  defp send_json_response(conn, {:ok, _}, action) do
    message = action.success_message || "Action completed successfully"
    send_json(conn, 200, %{success: true, message: message})
  end

  defp send_json_response(conn, {:error, reason}, action) do
    message = if is_binary(reason), do: reason, else: action.error_message || "Action failed"
    send_json(conn, 422, %{success: false, message: message})
  end

  defp load_selected_rows(table_module, %{"mode" => "explicit", "ids" => ids}, _params) do
    repo = table_module.repo()
    resource = table_module.resource()

    import Ecto.Query
    rows = repo.all(from(r in resource, where: r.id in ^ids))
    {:ok, rows}
  end

  defp load_selected_rows(table_module, %{"mode" => "all"}, params) do
    repo = table_module.repo()
    resource = table_module.resource()
    filters = Map.get(params, "filters", [])

    # Build Flop query without pagination
    flop_params = %{filters: parse_filters(filters)}

    case Flop.validate(flop_params, for: resource) do
      {:ok, flop} ->
        query = Flop.query(resource, flop)
        {:ok, repo.all(query)}

      {:error, _} ->
        {:ok, repo.all(resource)}
    end
  end

  defp load_selected_rows(table_module, %{"mode" => "all_except", "ids" => excluded_ids}, params) do
    repo = table_module.repo()
    resource = table_module.resource()
    filters = Map.get(params, "filters", [])

    import Ecto.Query

    flop_params = %{filters: parse_filters(filters)}

    query =
      case Flop.validate(flop_params, for: resource) do
        {:ok, flop} -> Flop.query(resource, flop)
        {:error, _} -> resource
      end

    rows = repo.all(from(r in query, where: r.id not in ^excluded_ids))
    {:ok, rows}
  end

  defp load_selected_rows(_table_module, _selection, _params) do
    {:error, "Invalid selection mode"}
  end

  defp parse_filters(filters) when is_list(filters) do
    Enum.map(filters, fn f ->
      %{
        field: String.to_existing_atom(f["field"]),
        op: parse_op(f["op"]),
        value: f["value"]
      }
    end)
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

  defp run_before_callback(%NbFlop.BulkAction{before: nil}, _rows), do: :ok

  defp run_before_callback(%NbFlop.BulkAction{before: before}, rows) do
    before.(rows)
  end

  defp run_after_callback(%NbFlop.BulkAction{after: nil}, _rows), do: :ok

  defp run_after_callback(%NbFlop.BulkAction{after: after_callback}, rows) do
    after_callback.(rows)
    :ok
  end

  defp execute_bulk_action(%NbFlop.BulkAction{handle: handle, chunk_size: chunk_size}, rows) do
    rows
    |> Stream.chunk_every(chunk_size)
    |> Enum.reduce_while(:ok, fn chunk, _acc ->
      case handle.(chunk) do
        :ok -> {:cont, :ok}
        {:ok, _} = result -> {:cont, result}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
    |> halt()
  end
end
