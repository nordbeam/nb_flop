defmodule NbFlop.Serializers.TableFilterOptionSerializer do
  @moduledoc """
  Serializer for filter option entries (for set filters).
  """
  use NbSerializer.Serializer

  schema do
    field(:value, :string)
    field(:label, :string)
  end
end
