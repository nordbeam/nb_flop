defmodule NbFlop.Table.DSL.RowFields do
  @moduledoc """
  DSL macros for declaring extra row fields added by `transform_row/3`.

  These declarations are used by nb_ts to generate accurate TypeScript types
  for table rows. Fields declared here don't affect the table display — they
  only inform the type system.

  ## Example

      row_fields do
        row_field :stats, :map, fields: [total: :number, success: :number, failed: :number]
        row_field :formatted_date, :string
        row_field :contact_id, :string, nullable: true
      end
  """

  @doc """
  Declares an extra field added by `transform_row/3` for TypeScript type generation.

  ## Supported types

    * `:string` - String value
    * `:number` - Numeric value
    * `:boolean` - Boolean value
    * `:map` - Object/map (use `fields:` option to declare shape)

  ## Options

    * `:nullable` - Whether the field can be null (default false)
    * `:fields` - For `:map` type, a keyword list of `{key, type}` pairs
  """
  defmacro row_field(key, type, opts \\ []) do
    quote do
      @nb_flop_ts_extra_fields {unquote(key), unquote(type), unquote(opts)}
    end
  end
end
