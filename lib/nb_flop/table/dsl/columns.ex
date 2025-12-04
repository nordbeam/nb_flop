defmodule NbFlop.Table.DSL.Columns do
  @moduledoc """
  DSL macros for defining table columns.
  """

  @doc """
  Defines a text column.

  ## Options

    * `:label` - Column header label
    * `:sortable` - Enable sorting (default false)
    * `:searchable` - Include in search (default false)
    * `:toggleable` - Can be hidden/shown (default true)
    * `:visible` - Initial visibility (default true)
    * `:alignment` - Text alignment (:left, :center, :right)
    * `:wrap` - Allow text wrapping (default false)
    * `:truncate` - Truncate long text (default false)
    * `:clickable` - Function returning URL for clickable cell
    * `:map_as` - Transform function for a single column value
    * `:compute` - Compute value from full row (for virtual/computed fields)
    * `:preload` - Association(s) to preload for this column (auto-merged with build opts)

  ## Examples

      # Basic text column
      text_column(:name, sortable: true)

      # Computed column from multiple fields
      text_column(:full_name,
        compute: fn row -> "\#{row.first_name} \#{row.last_name}" end
      )

      # Association column with compute and auto-preload
      text_column(:organization_name,
        preload: :organization,
        compute: fn row -> row.organization && row.organization.name end
      )

      # Nested association preload
      text_column(:manager_name,
        preload: [organization: :manager],
        compute: fn row -> row.organization && row.organization.manager.name end
      )
  """
  defmacro text_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:text, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines a badge column with color mapping.

  ## Options

  All text column options plus:

    * `:colors` - Map of value to color variant
      (e.g., `%{"active" => :success, "inactive" => :danger}`)
  """
  defmacro badge_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:badge, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines a numeric column with formatting.

  ## Options

  All text column options plus:

    * `:prefix` - Prefix string (e.g., "$")
    * `:suffix` - Suffix string (e.g., "%")
    * `:decimals` - Number of decimal places
    * `:thousands_separator` - Separator for thousands
  """
  defmacro numeric_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:numeric, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines a date column.

  ## Options

  All text column options plus:

    * `:format` - Date format string (default "MMM d, yyyy")
  """
  defmacro date_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:date, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines a datetime column.

  ## Options

  All text column options plus:

    * `:format` - DateTime format string
  """
  defmacro datetime_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:datetime, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines a boolean column.
  """
  defmacro boolean_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:boolean, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines an image column.

  ## Options

  All text column options plus:

    * `:width` - Image width in pixels (default 40)
    * `:height` - Image height in pixels (default 40)
    * `:rounded` - Use rounded corners (default false)
    * `:fallback` - Fallback image URL
  """
  defmacro image_column(key, opts \\ []) do
    quote do
      @nb_flop_columns {:image, unquote(key), unquote(Macro.escape(opts, unquote: true))}
    end
  end

  @doc """
  Defines the action column for row actions.

  ## Options

    * `:label` - Column header label (default "")
    * `:stickable` - Stick to right edge (default true)
  """
  defmacro action_column(opts \\ []) do
    quote do
      @nb_flop_columns {:action, :_actions, unquote(Macro.escape(opts, unquote: true))}
    end
  end
end
