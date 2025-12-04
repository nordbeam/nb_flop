defmodule NbFlop.Filter do
  @moduledoc """
  Filter definition struct for NbFlop tables.

  Filters define what filtering options are available for each field
  and map to Flop's filter capabilities.
  """

  @type filter_type :: :text | :numeric | :set | :date | :datetime | :boolean
  @type clause ::
          :equals
          | :not_equals
          | :contains
          | :starts_with
          | :ends_with
          | :gt
          | :gte
          | :lt
          | :lte
          | :between
          | :in
          | :not_in
          | :empty
          | :not_empty

  @type t :: %__MODULE__{
          field: atom(),
          type: filter_type(),
          label: String.t(),
          clauses: [clause()],
          default_clause: clause() | nil,
          options: [{String.t() | atom(), String.t()}] | nil,
          nullable: boolean(),
          min: any() | nil,
          max: any() | nil,
          # UI hints
          icon: String.t() | nil,
          placeholder: String.t() | nil,
          colors: %{(String.t() | atom()) => String.t()} | nil
        }

  defstruct [
    :field,
    :type,
    :label,
    :default_clause,
    :options,
    :min,
    :max,
    :icon,
    :placeholder,
    :colors,
    clauses: [],
    nullable: false
  ]

  @text_clauses [:equals, :not_equals, :contains, :starts_with, :ends_with, :empty, :not_empty]
  @numeric_clauses [:equals, :not_equals, :gt, :gte, :lt, :lte, :between, :empty, :not_empty]
  @set_clauses [:in, :not_in]
  @date_clauses [:equals, :not_equals, :gt, :gte, :lt, :lte, :between, :empty, :not_empty]
  @boolean_clauses [:equals]

  @doc """
  Creates a new Filter struct.
  """
  def new(field, type, opts \\ []) do
    label = Keyword.get(opts, :label, humanize(field))
    default_clauses = default_clauses(type)
    clauses = Keyword.get(opts, :clauses, default_clauses)
    default_clause = Keyword.get(opts, :default_clause, List.first(clauses))

    %__MODULE__{
      field: field,
      type: type,
      label: label,
      clauses: clauses,
      default_clause: default_clause,
      options: Keyword.get(opts, :options),
      nullable: Keyword.get(opts, :nullable, false),
      min: Keyword.get(opts, :min),
      max: Keyword.get(opts, :max),
      # UI hints
      icon: Keyword.get(opts, :icon),
      placeholder: Keyword.get(opts, :placeholder),
      colors: Keyword.get(opts, :colors)
    }
  end

  @doc """
  Creates a text filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses (default: all text clauses)
    * `:default_clause` - Default clause (default: first in list)
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI (e.g., "user", "mail")
    * `:placeholder` - Placeholder text for input
  """
  def text(field, opts \\ []) do
    new(field, :text, opts)
  end

  @doc """
  Creates a numeric filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses (default: all numeric clauses)
    * `:default_clause` - Default clause
    * `:min` - Minimum value
    * `:max` - Maximum value
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI
    * `:placeholder` - Placeholder text for input
  """
  def numeric(field, opts \\ []) do
    new(field, :numeric, opts)
  end

  @doc """
  Creates a set filter (multiple choice).

  ## Options

    * `:label` - Filter label
    * `:options` - List of `{value, label}` tuples
    * `:clauses` - List of allowed clauses (default: [:in, :not_in])
    * `:nullable` - Allow null matching
    * `:icon` - Icon hint for UI
    * `:colors` - Map of value to color (e.g., %{"active" => "success", "inactive" => "muted"})
  """
  def set(field, opts \\ []) do
    new(field, :set, opts)
  end

  @doc """
  Creates a date filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses (default: all date clauses)
    * `:default_clause` - Default clause
    * `:min` - Minimum date
    * `:max` - Maximum date
    * `:nullable` - Allow null matching
  """
  def date(field, opts \\ []) do
    new(field, :date, opts)
  end

  @doc """
  Creates a datetime filter.

  ## Options

    * `:label` - Filter label
    * `:clauses` - List of allowed clauses
    * `:default_clause` - Default clause
    * `:min` - Minimum datetime
    * `:max` - Maximum datetime
    * `:nullable` - Allow null matching
  """
  def datetime(field, opts \\ []) do
    new(field, :datetime, opts)
  end

  @doc """
  Creates a boolean filter.

  ## Options

    * `:label` - Filter label
    * `:nullable` - Allow null matching (for tri-state)
  """
  def boolean(field, opts \\ []) do
    new(field, :boolean, opts)
  end

  @doc """
  Converts a Flop operator atom to a clause atom.
  """
  def flop_op_to_clause(:==), do: :equals
  def flop_op_to_clause(:!=), do: :not_equals
  def flop_op_to_clause(:ilike), do: :contains
  def flop_op_to_clause(:like), do: :contains
  def flop_op_to_clause(:=~), do: :contains
  def flop_op_to_clause(:>), do: :gt
  def flop_op_to_clause(:>=), do: :gte
  def flop_op_to_clause(:<), do: :lt
  def flop_op_to_clause(:<=), do: :lte
  def flop_op_to_clause(:in), do: :in
  def flop_op_to_clause(:not_in), do: :not_in
  def flop_op_to_clause(:empty), do: :empty
  def flop_op_to_clause(:not_empty), do: :not_empty
  def flop_op_to_clause(op), do: op

  @doc """
  Converts a clause atom to a Flop operator atom.
  """
  def clause_to_flop_op(:equals), do: :==
  def clause_to_flop_op(:not_equals), do: :!=
  def clause_to_flop_op(:contains), do: :ilike
  def clause_to_flop_op(:starts_with), do: :ilike
  def clause_to_flop_op(:ends_with), do: :ilike
  def clause_to_flop_op(:gt), do: :>
  def clause_to_flop_op(:gte), do: :>=
  def clause_to_flop_op(:lt), do: :<
  def clause_to_flop_op(:lte), do: :<=
  def clause_to_flop_op(:in), do: :in
  def clause_to_flop_op(:not_in), do: :not_in
  def clause_to_flop_op(:empty), do: :empty
  def clause_to_flop_op(:not_empty), do: :not_empty
  def clause_to_flop_op(:between), do: :between
  def clause_to_flop_op(clause), do: clause

  # Private helpers

  defp humanize(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp default_clauses(:text), do: @text_clauses
  defp default_clauses(:numeric), do: @numeric_clauses
  defp default_clauses(:set), do: @set_clauses
  defp default_clauses(:date), do: @date_clauses
  defp default_clauses(:datetime), do: @date_clauses
  defp default_clauses(:boolean), do: @boolean_clauses
end
