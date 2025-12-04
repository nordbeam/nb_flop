defmodule NbFlop.Serializers.TableViewsSerializer do
  @moduledoc """
  Serializer for table saved views configuration.
  """
  use NbSerializer.Serializer

  schema do
    field(:enabled, :boolean)
    field(:list, list: :map)
    field(:current, :map, nullable: true)
  end
end
