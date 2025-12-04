defmodule NbFlop.Exporters.CSVExporter do
  @moduledoc """
  CSV exporter for NbFlop tables.

  Uses the `csv` library (https://github.com/beatrichartz/csv) to generate
  CSV files from table data with proper escaping and formatting.

  ## Usage

      # In your controller
      def export(conn, params) do
        export = Enum.find(UsersTable.exports(), &(&1.name == :csv))

        {rows, _meta} = UsersTable.query(params)

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", "attachment; filename=\"users.csv\"")
        |> send_resp(200, NbFlop.Exporters.CSVExporter.generate(UsersTable, rows, export))
      end
  """

  alias NbFlop.Column
  alias NbFlop.Export

  @doc """
  Generates a CSV string from table rows.

  ## Options

    * `:columns` - List of column keys to export (default: all visible columns except :action)
    * `:format_column` - Map of column key to formatter function
    * `:headers` - Whether to include headers (default: true)
    * `:delimiter` - Field delimiter (default: ",")
    * `:line_separator` - Line separator (default: "\\r\\n")

  ## Examples

      # Export all columns
      csv = CSVExporter.generate(UsersTable, rows)

      # Export specific columns
      csv = CSVExporter.generate(UsersTable, rows, export)

      # Export with custom formatters
      export = %Export{
        format_column: %{
          status: fn val -> String.upcase(to_string(val)) end
        }
      }
      csv = CSVExporter.generate(UsersTable, rows, export)
  """
  @spec generate(module(), [map()], Export.t() | nil, keyword()) :: String.t()
  def generate(table_module, rows, export \\ nil, opts \\ []) do
    columns = get_export_columns(table_module, export)
    formatters = get_formatters(export)
    include_headers = Keyword.get(opts, :headers, true)
    delimiter = Keyword.get(opts, :delimiter, ",")
    line_separator = Keyword.get(opts, :line_separator, "\r\n")

    data_rows =
      Enum.map(rows, fn row ->
        Enum.map(columns, fn col ->
          value = extract_value(row, col)
          format_value(value, col, formatters)
        end)
      end)

    all_rows =
      if include_headers do
        headers = Enum.map(columns, & &1.label)
        [headers | data_rows]
      else
        data_rows
      end

    all_rows
    |> CSV.encode(separator: delimiter_char(delimiter), line_separator: line_separator)
    |> Enum.join()
  end

  @doc """
  Streams CSV data for large exports.

  Returns a Stream that can be used with `Plug.Conn.chunk/2` for
  memory-efficient exports of large datasets.

  ## Examples

      def export(conn, params) do
        export = Enum.find(UsersTable.exports(), &(&1.name == :csv))

        conn =
          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"users.csv\"")
          |> send_chunked(200)

        stream = UsersTable.query_stream(params)
        csv_stream = CSVExporter.stream(UsersTable, stream, export)

        Enum.reduce_while(csv_stream, conn, fn chunk, conn ->
          case Plug.Conn.chunk(conn, chunk) do
            {:ok, conn} -> {:cont, conn}
            {:error, :closed} -> {:halt, conn}
          end
        end)
      end
  """
  @spec stream(module(), Enumerable.t(), Export.t() | nil, keyword()) :: Enumerable.t()
  def stream(table_module, rows_stream, export \\ nil, opts \\ []) do
    columns = get_export_columns(table_module, export)
    formatters = get_formatters(export)
    include_headers = Keyword.get(opts, :headers, true)
    delimiter = Keyword.get(opts, :delimiter, ",")
    line_separator = Keyword.get(opts, :line_separator, "\r\n")

    header_stream =
      if include_headers do
        headers = Enum.map(columns, & &1.label)
        Stream.map([headers], & &1)
      else
        Stream.map([], & &1)
      end

    data_stream =
      Stream.map(rows_stream, fn row ->
        Enum.map(columns, fn col ->
          value = extract_value(row, col)
          format_value(value, col, formatters)
        end)
      end)

    Stream.concat(header_stream, data_stream)
    |> CSV.encode(separator: delimiter_char(delimiter), line_separator: line_separator)
  end

  @doc """
  Generates a filename for the export.

  If the export has a filename function, it will be called with metadata.
  Otherwise, a default filename is generated using the table name and timestamp.
  """
  @spec generate_filename(module(), Export.t() | nil, map()) :: String.t()
  def generate_filename(table_module, export, meta \\ %{}) do
    cond do
      export && export.filename ->
        export.filename.(meta)

      true ->
        config = table_module.config()
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
        "#{config.name}_#{timestamp}.csv"
    end
  end

  # Private helpers

  defp get_export_columns(table_module, export) do
    all_columns = table_module.columns()

    export_columns =
      if export && export.columns do
        # Filter to only requested columns in specified order
        Enum.reduce(export.columns, [], fn key, acc ->
          case Enum.find(all_columns, &(&1.key == key)) do
            nil -> acc
            col -> acc ++ [col]
          end
        end)
      else
        # Default: all visible, non-action columns
        Enum.filter(all_columns, fn col ->
          col.type != :action && col.visible
        end)
      end

    export_columns
  end

  defp get_formatters(nil), do: %{}
  defp get_formatters(%Export{format_column: nil}), do: %{}
  defp get_formatters(%Export{format_column: formatters}), do: formatters

  defp extract_value(row, %Column{key: key, map_as: nil}) do
    case row do
      %{^key => value} -> value
      _ when is_struct(row) -> Map.get(row, key)
      _ -> nil
    end
  end

  defp extract_value(row, %Column{key: key, map_as: map_as}) do
    raw_value =
      case row do
        %{^key => value} -> value
        _ when is_struct(row) -> Map.get(row, key)
        _ -> nil
      end

    map_as.(raw_value)
  end

  defp format_value(value, %Column{key: key} = col, formatters) do
    # First apply custom formatter if exists
    formatted =
      case Map.get(formatters, key) do
        nil -> value
        formatter -> formatter.(value)
      end

    # Then convert to string for CSV
    value_to_string(formatted, col)
  end

  defp value_to_string(nil, _col), do: ""
  defp value_to_string(value, _col) when is_binary(value), do: value
  defp value_to_string(value, _col) when is_number(value), do: to_string(value)
  defp value_to_string(value, _col) when is_boolean(value), do: to_string(value)
  defp value_to_string(value, _col) when is_atom(value), do: to_string(value)

  defp value_to_string(%Date{} = date, %Column{type: :date, opts: opts}) do
    format = Map.get(opts, :format, "yyyy-MM-dd")
    format_date(date, format)
  end

  defp value_to_string(%DateTime{} = dt, %Column{type: :datetime, opts: opts}) do
    format = Map.get(opts, :format, "yyyy-MM-dd HH:mm:ss")
    format_datetime(dt, format)
  end

  defp value_to_string(%NaiveDateTime{} = dt, %Column{type: :datetime, opts: opts}) do
    format = Map.get(opts, :format, "yyyy-MM-dd HH:mm:ss")
    format_naive_datetime(dt, format)
  end

  defp value_to_string(%Date{} = date, _col) do
    Date.to_iso8601(date)
  end

  defp value_to_string(%DateTime{} = dt, _col) do
    DateTime.to_iso8601(dt)
  end

  defp value_to_string(%NaiveDateTime{} = dt, _col) do
    NaiveDateTime.to_iso8601(dt)
  end

  defp value_to_string(value, _col) when is_list(value) do
    Enum.join(value, ", ")
  end

  defp value_to_string(value, _col) when is_map(value) do
    Jason.encode!(value)
  end

  defp value_to_string(value, _col) do
    inspect(value)
  end

  # Simple date/datetime formatting using Calendar.strftime
  # These formats are simplified - for full format support, users should
  # use format_column callbacks with their preferred date library

  defp format_date(date, _format) do
    # For CSV exports, ISO8601 is typically preferred
    # Users can use format_column for custom formats
    Date.to_iso8601(date)
  end

  defp format_datetime(dt, _format) do
    DateTime.to_iso8601(dt)
  end

  defp format_naive_datetime(dt, _format) do
    NaiveDateTime.to_iso8601(dt)
  end

  defp delimiter_char(","), do: ?,
  defp delimiter_char(";"), do: ?;
  defp delimiter_char("\t"), do: ?\t
  defp delimiter_char(char) when is_binary(char), do: String.to_charlist(char) |> hd()
  defp delimiter_char(char) when is_integer(char), do: char
end
