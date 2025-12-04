defmodule NbFlop.Serializers.TableFilterSerializer do
  @moduledoc """
  Serializer for table filter definitions.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.TableFilterOptionSerializer

  schema do
    field(:field, :string)
    field(:type, :string)
    field(:label, :string, nullable: true)
    field(:clauses, list: :string)
    field(:default_clause, :string)
    field(:nullable, :boolean)
    field(:min, :any, nullable: true)
    field(:max, :any, nullable: true)

    # UI hints
    field(:icon, :string, nullable: true)
    field(:placeholder, :string, nullable: true)
    field(:colors, :map, nullable: true)

    has_many(:options, TableFilterOptionSerializer)
  end
end
