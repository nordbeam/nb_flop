defmodule NbFlop.Serializers.TableFlopSerializer do
  @moduledoc """
  Serializer for the flop params within meta.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.TableFlopFilterSerializer

  schema do
    field(:order_by, list: :string, nullable: true)
    field(:order_directions, list: :string, nullable: true)
    field(:page, :number, nullable: true)
    field(:page_size, :number, nullable: true)

    has_many(:filters, TableFlopFilterSerializer)
  end
end
