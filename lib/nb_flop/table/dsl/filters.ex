defmodule NbFlop.Table.DSL.Filters do
  @moduledoc """
  DSL macros for defining table filters.

  ## UI Hints

  All filter types support common UI hints that are passed to the frontend:

    * `:icon` - Icon hint for UI rendering (e.g., "user", "mail", "calendar")
    * `:placeholder` - Placeholder text for filter input

  Set filters additionally support:

    * `:colors` - Map of value to color variant (e.g., %{"active" => "success"})

  ## Example

      filters do
        text_filter :name,
          label: "Name",
          icon: "user",
          placeholder: "Search by name..."

        set_filter :status,
          label: "Status",
          options: [{"active", "Active"}, {"inactive", "Inactive"}],
          icon: "circle",
          colors: %{"active" => "success", "inactive" => "muted"}

        numeric_filter :amount,
          label: "Amount",
          min: 0,
          max: 10000,
          icon: "dollar-sign"

        date_filter :created_at,
          label: "Created",
          icon: "calendar"
      end
  """

  @doc """
  Defines a text filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses (default: all text clauses)
    * `:default_clause` - Default clause
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI (e.g., "user", "mail")
    * `:placeholder` - Placeholder text for input
  """
  defmacro text_filter(field, opts \\ []) do
    quote do
      @nb_flop_filters NbFlop.Filter.text(unquote(field), unquote(opts))
    end
  end

  @doc """
  Defines a numeric filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses
    * `:default_clause` - Default clause
    * `:min` - Minimum value
    * `:max` - Maximum value
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI
    * `:placeholder` - Placeholder text for input
  """
  defmacro numeric_filter(field, opts \\ []) do
    quote do
      @nb_flop_filters NbFlop.Filter.numeric(unquote(field), unquote(opts))
    end
  end

  @doc """
  Defines a set filter (multiple choice).

  ## Options

    * `:label` - Filter label
    * `:options` - List of `{value, label}` tuples
    * `:clauses` - List of allowed clauses (default: [:in, :not_in])
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI
    * `:colors` - Map of value to color variant (e.g., %{"active" => "success"})
  """
  defmacro set_filter(field, opts \\ []) do
    quote do
      @nb_flop_filters NbFlop.Filter.set(unquote(field), unquote(opts))
    end
  end

  @doc """
  Defines a date filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses
    * `:default_clause` - Default clause
    * `:min` - Minimum date
    * `:max` - Maximum date
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI
    * `:placeholder` - Placeholder text for input
  """
  defmacro date_filter(field, opts \\ []) do
    quote do
      @nb_flop_filters NbFlop.Filter.date(unquote(field), unquote(opts))
    end
  end

  @doc """
  Defines a datetime filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses
    * `:default_clause` - Default clause
    * `:min` - Minimum datetime
    * `:max` - Maximum datetime
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI
    * `:placeholder` - Placeholder text for input
  """
  defmacro datetime_filter(field, opts \\ []) do
    quote do
      @nb_flop_filters NbFlop.Filter.datetime(unquote(field), unquote(opts))
    end
  end

  @doc """
  Defines a boolean filter.

  ## Options

    * `:label` - Filter label
    * `:nullable` - Allow null matching (for tri-state)
    * `:icon` - Icon hint for UI
  """
  defmacro boolean_filter(field, opts \\ []) do
    quote do
      @nb_flop_filters NbFlop.Filter.boolean(unquote(field), unquote(opts))
    end
  end
end
