defmodule NbFlop.Table.Config do
  @moduledoc """
  Configuration struct for NbFlop tables.

  Contains settings like name, default sorting, pagination options, and search configuration.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          default_sort: {atom(), :asc | :desc} | nil,
          default_per_page: pos_integer(),
          per_page_options: [pos_integer()],
          sticky_header: boolean(),
          searchable: [atom()] | false,
          search_placeholder: String.t() | nil
        }

  @enforce_keys [:name]
  defstruct [
    :name,
    :default_sort,
    default_per_page: 25,
    per_page_options: [10, 25, 50, 100],
    sticky_header: false,
    searchable: false,
    search_placeholder: nil
  ]

  @doc """
  Creates a new Config struct with the given options.

  ## Options

    * `:name` - Required. The table name, used for URL namespacing.
    * `:default_sort` - Default sort as `{field, direction}` tuple.
    * `:default_per_page` - Default page size. Defaults to 25.
    * `:per_page_options` - Available page size options. Defaults to `[10, 25, 50, 100]`.
    * `:sticky_header` - Whether to use sticky header. Defaults to `false`.
    * `:searchable` - List of searchable fields or `false`. Defaults to `false`.
    * `:search_placeholder` - Placeholder text for search input.
  """
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Returns default configuration with the given name.
  """
  def default(name) when is_binary(name) do
    %__MODULE__{name: name}
  end
end
