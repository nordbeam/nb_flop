defmodule NbFlop.Table.DSL.Exports do
  @moduledoc """
  DSL macros for defining table exports.
  """

  @doc """
  Defines an export format.

  ## Options

    * `:label` - Export button label
    * `:format` - Export format (:csv, :excel, :pdf)
    * `:columns` - List of columns to export (default: all)
    * `:format_column` - Map of column to formatter function
    * `:filename` - Function to generate filename
    * `:authorize` - Function to check if user can export
    * `:queue` - Queue large exports (for async processing)

  ## Examples

      export :csv, columns: [:name, :email, :status]

      export :excel,
        columns: [:name, :email, :status, :created_at],
        format_column: %{
          created_at: fn dt -> Calendar.strftime(dt, "%Y-%m-%d") end
        }
  """
  defmacro export(name, opts \\ []) do
    quote do
      @nb_flop_exports NbFlop.Export.new(unquote(name), unquote(opts))
    end
  end
end
