defmodule NbFlop.Serializers.TableEmptyStateSerializer do
  @moduledoc """
  Serializer for table empty state configuration.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.TableEmptyStateActionSerializer

  schema do
    field(:title, :string)
    field(:message, :string, nullable: true)
    field(:icon, :string, nullable: true)
    has_one(:action, serializer: TableEmptyStateActionSerializer, nullable: true)
  end
end
