defmodule NbFlop.Serializers.TableMetaSerializer do
  @moduledoc """
  Serializer for table pagination metadata.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.TableFlopSerializer

  schema do
    field(:current_page, :number, nullable: true)
    field(:total_pages, :number, nullable: true)
    field(:total_count, :number, nullable: true)
    field(:page_size, :number, nullable: true)
    field(:has_next_page, :boolean)
    field(:has_previous_page, :boolean)
    field(:next_page, :number, nullable: true)
    field(:previous_page, :number, nullable: true)
    field(:start_cursor, :string, nullable: true)
    field(:end_cursor, :string, nullable: true)

    has_one(:flop, serializer: TableFlopSerializer, nullable: true)
  end
end
