defmodule NbFlop.Serializers.TableEmptyStateActionSerializer do
  @moduledoc """
  Serializer for empty state action button configuration.
  """
  use NbSerializer.Serializer

  schema do
    field(:label, :string)
    field(:url, :string)
    field(:variant, :string)
  end
end
