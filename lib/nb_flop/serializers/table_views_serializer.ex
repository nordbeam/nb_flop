defmodule NbFlop.Serializers.TableViewsSerializer do
  @moduledoc """
  Serializer for table saved views configuration.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.TableViewItemSerializer

  schema do
    field(:enabled, :boolean)
    has_many(:list, serializer: TableViewItemSerializer)
    has_one(:current, serializer: TableViewItemSerializer, nullable: true)
  end
end
