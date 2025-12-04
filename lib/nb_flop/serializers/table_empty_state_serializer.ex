defmodule NbFlop.Serializers.TableEmptyStateSerializer do
  @moduledoc """
  Serializer for table empty state configuration.
  """
  use NbSerializer.Serializer

  schema do
    field(:title, :string)
    field(:message, :string, nullable: true)
    field(:icon, :string, nullable: true)
    field(:action, :map, nullable: true)
  end
end
