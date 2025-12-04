defmodule NbFlop.Serializers.TableBulkActionSerializer do
  @moduledoc """
  Serializer for table bulk action definitions.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.TableConfirmationSerializer

  schema do
    field(:name, :string)
    field(:label, :string, nullable: true)
    field(:variant, :string)
    field(:icon, :string, nullable: true)
    field(:frontend, :boolean)

    has_one(:confirmation, serializer: TableConfirmationSerializer, nullable: true)
  end
end
