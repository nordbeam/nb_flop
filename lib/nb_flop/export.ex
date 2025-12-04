defmodule NbFlop.Export do
  @moduledoc """
  Export definition struct for NbFlop tables.

  Exports allow users to download table data in various formats.
  """

  @type format :: :csv | :excel | :pdf

  @type t :: %__MODULE__{
          name: atom(),
          label: String.t(),
          format: format(),
          columns: [atom()] | nil,
          format_column: %{atom() => (any() -> String.t())} | nil,
          filename: (map() -> String.t()) | nil,
          authorize: (Plug.Conn.t() -> boolean()) | nil,
          queue: boolean()
        }

  defstruct [
    :name,
    :label,
    :format,
    :columns,
    :format_column,
    :filename,
    :authorize,
    queue: false
  ]

  @doc """
  Creates a new Export struct.

  ## Options

    * `:label` - Export button label
    * `:format` - Export format (:csv, :excel, :pdf)
    * `:columns` - List of columns to export (default: all)
    * `:format_column` - Map of column to formatter function
    * `:filename` - Function to generate filename
    * `:authorize` - Function to check if user can export
    * `:queue` - Queue large exports (for async processing)
  """
  def new(name, opts \\ []) do
    format = Keyword.get(opts, :format, infer_format(name))
    label = Keyword.get(opts, :label, default_label(format))

    %__MODULE__{
      name: name,
      label: label,
      format: format,
      columns: Keyword.get(opts, :columns),
      format_column: Keyword.get(opts, :format_column),
      filename: Keyword.get(opts, :filename),
      authorize: Keyword.get(opts, :authorize),
      queue: Keyword.get(opts, :queue, false)
    }
  end

  defp infer_format(:csv), do: :csv
  defp infer_format(:excel), do: :excel
  defp infer_format(:pdf), do: :pdf
  defp infer_format(_), do: :csv

  defp default_label(:csv), do: "Export CSV"
  defp default_label(:excel), do: "Export Excel"
  defp default_label(:pdf), do: "Export PDF"
end
