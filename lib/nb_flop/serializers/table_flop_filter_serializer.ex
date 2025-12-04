defmodule NbFlop.Serializers.TableFlopFilterSerializer do
  @moduledoc """
  Serializer for individual flop filter entries.
  """
  use NbSerializer.Serializer

  schema do
    field(:field, :string)
    field(:op, :string)
    field(:value, :any)
  end
end
