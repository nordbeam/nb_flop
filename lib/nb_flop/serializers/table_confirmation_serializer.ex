defmodule NbFlop.Serializers.TableConfirmationSerializer do
  @moduledoc """
  Serializer for action confirmation dialogs.
  """
  use NbSerializer.Serializer

  schema do
    field(:title, :string)
    field(:message, :string)
    field(:confirm_button, :string, nullable: true)
    field(:cancel_button, :string, nullable: true)
    field(:variant, :string)
    field(:icon, :string, nullable: true)
  end
end
