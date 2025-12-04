defmodule NbFlop.Serializers.TableStateSerializer do
  @moduledoc """
  Serializer for table state (current sort, filters, page, etc.).
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.{TableSortStateSerializer, TableFlopFilterSerializer}

  schema do
    field(:page, :number)
    field(:per_page, :number)
    field(:search, :string, nullable: true)
    field(:columns, list: :string)

    has_one(:sort, serializer: TableSortStateSerializer, nullable: true)
    has_many(:filters, TableFlopFilterSerializer)
  end
end
