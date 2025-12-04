defmodule NbFlop.Serializers.TableColumnSerializer do
  @moduledoc """
  Serializer for table column definitions.
  """
  use NbSerializer.Serializer

  schema do
    field(:key, :string)
    field(:type, :string)
    field(:label, :string, nullable: true)
    field(:sortable, :boolean)
    field(:searchable, :boolean)
    field(:toggleable, :boolean)
    field(:visible, :boolean)
    field(:stickable, :boolean)
    field(:alignment, :string)
    field(:wrap, :boolean)
    field(:truncate, :boolean)
    field(:header_class, :string, nullable: true)
    field(:cell_class, :string, nullable: true)

    # Type-specific options (badge, numeric, date, image)
    field(:colors, :map, nullable: true)
    field(:prefix, :string, nullable: true)
    field(:suffix, :string, nullable: true)
    field(:decimals, :number, nullable: true)
    field(:thousands_separator, :string, nullable: true)
    field(:format, :string, nullable: true)
    field(:width, :number, nullable: true)
    field(:height, :number, nullable: true)
    field(:rounded, :boolean, nullable: true)
    field(:fallback, :string, nullable: true)
  end
end
