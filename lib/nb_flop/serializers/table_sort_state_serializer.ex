defmodule NbFlop.Serializers.TableSortStateSerializer do
  @moduledoc """
  Serializer for current sort state.
  """
  use NbSerializer.Serializer

  schema do
    field(:field, :string)
    field(:direction, :string)
  end
end
