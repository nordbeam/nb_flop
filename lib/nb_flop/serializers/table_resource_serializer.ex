defmodule NbFlop.Serializers.TableResourceSerializer do
  @moduledoc """
  Serializer for the Table DSL resource structure.

  This serializer defines the shape of the data returned by `Table.make/3`,
  enabling proper TypeScript type generation with nb_ts.

  ## Usage

      inertia_page :users_index do
        prop(:users, TableResourceSerializer)
      end

      def index(conn, params) do
        render_inertia(conn, :users_index,
          users: UsersTable.make(conn, params)
        )
      end

  ## Generic Row Data

  The `data` field contains row-specific data that varies per table.
  Use the `:row_serializer` option to specify the row type:

      prop(:users, {TableResourceSerializer, row_serializer: UserRowSerializer})

  If no row_serializer is specified, rows are typed as `Record<string, any>`.
  """
  use NbSerializer.Serializer

  alias NbFlop.Serializers.{
    TableMetaSerializer,
    TableStateSerializer,
    TableColumnSerializer,
    TableFilterSerializer,
    TableActionSerializer,
    TableBulkActionSerializer,
    TableExportSerializer,
    TableEmptyStateSerializer,
    TableViewsSerializer
  }

  schema do
    field(:name, :string)
    field(:token, :string, nullable: true)
    field(:data, :any)
    field(:per_page_options, list: :number)
    field(:sticky_header, :boolean)
    field(:searchable, list: :string)
    field(:search_placeholder, :string, nullable: true)
    field(:error, :any, nullable: true)

    has_one(:meta, TableMetaSerializer)
    has_one(:state, TableStateSerializer)
    has_one(:empty_state, serializer: TableEmptyStateSerializer, nullable: true)
    has_one(:views, TableViewsSerializer)

    has_many(:columns, TableColumnSerializer)
    has_many(:filters, TableFilterSerializer)
    has_many(:actions, TableActionSerializer)
    has_many(:bulk_actions, TableBulkActionSerializer)
    has_many(:exports, TableExportSerializer)
  end
end
