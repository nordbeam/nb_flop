defmodule NbFlop.Column do
  @moduledoc """
  Column definition struct for NbFlop tables.

  Columns define how data is displayed and what operations are available
  (sorting, searching, visibility toggle, etc.)
  """

  @type column_type :: :text | :badge | :numeric | :date | :datetime | :boolean | :image | :action
  @type alignment :: :left | :center | :right

  @type t :: %__MODULE__{
          key: atom(),
          type: column_type(),
          label: String.t(),
          sortable: boolean(),
          searchable: boolean(),
          toggleable: boolean(),
          visible: boolean(),
          stickable: boolean(),
          alignment: alignment(),
          wrap: boolean(),
          truncate: boolean(),
          header_class: String.t() | nil,
          cell_class: String.t() | nil,
          clickable: (map() -> String.t() | nil) | nil,
          map_as: (any() -> any()) | nil,
          compute: (map() -> any()) | nil,
          preload: atom() | [atom()] | keyword() | nil,
          meta: map(),
          opts: map()
        }

  defstruct [
    :key,
    :type,
    :label,
    :clickable,
    :map_as,
    :compute,
    :preload,
    sortable: false,
    searchable: false,
    toggleable: true,
    visible: true,
    stickable: false,
    alignment: :left,
    wrap: false,
    truncate: false,
    header_class: nil,
    cell_class: nil,
    meta: %{},
    opts: %{}
  ]

  @doc """
  Creates a new Column struct.
  """
  def new(key, type, opts \\ []) do
    label = Keyword.get(opts, :label, humanize(key))
    type_opts = extract_type_opts(type, opts)

    %__MODULE__{
      key: key,
      type: type,
      label: label,
      sortable: Keyword.get(opts, :sortable, false),
      searchable: Keyword.get(opts, :searchable, false),
      toggleable: Keyword.get(opts, :toggleable, true),
      visible: Keyword.get(opts, :visible, true),
      stickable: Keyword.get(opts, :stickable, false),
      alignment: Keyword.get(opts, :alignment, default_alignment(type)),
      wrap: Keyword.get(opts, :wrap, false),
      truncate: Keyword.get(opts, :truncate, false),
      header_class: Keyword.get(opts, :header_class),
      cell_class: Keyword.get(opts, :cell_class),
      clickable: Keyword.get(opts, :clickable),
      map_as: Keyword.get(opts, :map_as),
      compute: Keyword.get(opts, :compute),
      preload: Keyword.get(opts, :preload),
      meta: Keyword.get(opts, :meta, %{}),
      opts: type_opts
    }
  end

  @doc """
  Collects all preload requirements from a list of columns.

  Returns a list of preloads suitable for passing to `Repo.preload/2`.
  """
  def collect_preloads(columns) when is_list(columns) do
    columns
    |> Enum.map(& &1.preload)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> normalize_preloads()
  end

  defp normalize_preloads([]), do: []

  defp normalize_preloads(preloads) do
    # Flatten and merge preloads into a single list
    # Handles atoms, lists, and keyword lists
    Enum.flat_map(preloads, fn
      preload when is_atom(preload) -> [preload]
      preload when is_list(preload) -> preload
    end)
    |> Enum.uniq()
  end

  @doc """
  Creates a text column.
  """
  def text(key, opts \\ []) do
    new(key, :text, opts)
  end

  @doc """
  Creates a badge column with color mapping.

  ## Options

    * `:colors` - Map of value to color variant (e.g., `%{"active" => :success}`)
  """
  def badge(key, opts \\ []) do
    new(key, :badge, opts)
  end

  @doc """
  Creates a numeric column with formatting options.

  ## Options

    * `:prefix` - Prefix string (e.g., "$")
    * `:suffix` - Suffix string (e.g., "%")
    * `:decimals` - Number of decimal places
    * `:thousands_separator` - Separator for thousands (default ",")
  """
  def numeric(key, opts \\ []) do
    new(key, :numeric, Keyword.put_new(opts, :alignment, :right))
  end

  @doc """
  Creates a date column.

  ## Options

    * `:format` - Date format string (default "MMM d, yyyy")
  """
  def date(key, opts \\ []) do
    new(key, :date, opts)
  end

  @doc """
  Creates a datetime column.

  ## Options

    * `:format` - DateTime format string
  """
  def datetime(key, opts \\ []) do
    new(key, :datetime, opts)
  end

  @doc """
  Creates a boolean column.
  """
  def boolean(key, opts \\ []) do
    new(key, :boolean, Keyword.put_new(opts, :alignment, :center))
  end

  @doc """
  Creates an image column.

  ## Options

    * `:width` - Image width in pixels
    * `:height` - Image height in pixels
    * `:rounded` - Whether to use rounded corners
    * `:fallback` - Fallback image URL
  """
  def image(key, opts \\ []) do
    new(key, :image, Keyword.put_new(opts, :alignment, :center))
  end

  @doc """
  Creates the action column for row actions.
  """
  def action(opts \\ []) do
    %__MODULE__{
      key: :_actions,
      type: :action,
      label: Keyword.get(opts, :label, ""),
      sortable: false,
      searchable: false,
      toggleable: false,
      visible: true,
      stickable: Keyword.get(opts, :stickable, true),
      alignment: :right,
      wrap: false,
      truncate: false,
      opts: %{}
    }
  end

  # Private helpers

  defp humanize(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp default_alignment(:numeric), do: :right
  defp default_alignment(:boolean), do: :center
  defp default_alignment(:image), do: :center
  defp default_alignment(:action), do: :right
  defp default_alignment(_), do: :left

  defp extract_type_opts(:badge, opts) do
    %{
      colors: Keyword.get(opts, :colors, %{})
    }
  end

  defp extract_type_opts(:numeric, opts) do
    %{
      prefix: Keyword.get(opts, :prefix),
      suffix: Keyword.get(opts, :suffix),
      decimals: Keyword.get(opts, :decimals),
      thousands_separator: Keyword.get(opts, :thousands_separator, ",")
    }
  end

  defp extract_type_opts(:date, opts) do
    %{
      format: Keyword.get(opts, :format, "MMM d, yyyy")
    }
  end

  defp extract_type_opts(:datetime, opts) do
    %{
      format: Keyword.get(opts, :format, "MMM d, yyyy h:mm a")
    }
  end

  defp extract_type_opts(:image, opts) do
    %{
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 40),
      rounded: Keyword.get(opts, :rounded, false),
      fallback: Keyword.get(opts, :fallback)
    }
  end

  defp extract_type_opts(_, _opts), do: %{}
end
