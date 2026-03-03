defmodule NbFlop.Serializers.TableViewItemSerializer do
  @moduledoc """
  Serializer for a saved table view item.
  """
  use NbSerializer.Serializer

  schema do
    field(:id, :string)
    field(:name, :string)
    field(:default, :boolean)
  end
end
