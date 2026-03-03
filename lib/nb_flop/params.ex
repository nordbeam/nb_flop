defmodule NbFlop.Params do
  @moduledoc """
  Shared parameter parsing for filter operators and filter lists.

  Used by Builder, ActionController, ExportController, and Rpc to avoid
  duplicating operator/filter parsing logic.
  """

  @doc """
  Parses a filter operator string into an atom.

  Handles all Flop operators including comparison, pattern matching, and set operators.
  """
  @spec parse_op(atom() | String.t() | nil) :: atom()
  def parse_op(nil), do: :==
  def parse_op(op) when is_atom(op), do: op
  def parse_op("=="), do: :==
  def parse_op("!="), do: :!=
  def parse_op("ilike"), do: :ilike
  def parse_op("contains"), do: :ilike
  def parse_op(">"), do: :>
  def parse_op(">="), do: :>=
  def parse_op("<"), do: :<
  def parse_op("<="), do: :<=
  def parse_op("in"), do: :in
  def parse_op("not_in"), do: :not_in
  def parse_op("like_and"), do: :like_and
  def parse_op("like_or"), do: :like_or
  def parse_op("ilike_and"), do: :ilike_and
  def parse_op("ilike_or"), do: :ilike_or
  def parse_op("empty"), do: :empty
  def parse_op("not_empty"), do: :not_empty
  def parse_op(op) when is_binary(op), do: String.to_existing_atom(op)

  @doc """
  Parses a list of filter maps into Flop-compatible filter structs.

  Accepts filters as either string-keyed maps (from HTTP params) or
  atom-keyed maps (from RPC input). Returns an empty list on error.
  """
  @spec parse_filters(list() | term()) :: [map()]
  def parse_filters(filters) when is_list(filters) do
    Enum.map(filters, fn f ->
      %{
        field: String.to_existing_atom(to_string(f["field"] || f[:field])),
        op: parse_op(f["op"] || f[:op]),
        value: f["value"] || f[:value]
      }
    end)
  rescue
    _ -> []
  end

  def parse_filters(_), do: []

  @doc """
  Parses JSON-encoded filters from export query params.
  """
  @spec parse_filters_json(String.t()) :: [map()]
  def parse_filters_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, filters} when is_list(filters) -> parse_filters(filters)
      _ -> []
    end
  rescue
    _ -> []
  end

  def parse_filters_json(_), do: []
end
