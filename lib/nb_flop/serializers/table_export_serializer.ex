defmodule NbFlop.Serializers.TableExportSerializer do
  @moduledoc """
  Serializer for table export definitions.
  """
  use NbSerializer.Serializer

  schema do
    field(:name, :string)
    field(:label, :string, nullable: true)
    field(:format, :string)
  end
end
