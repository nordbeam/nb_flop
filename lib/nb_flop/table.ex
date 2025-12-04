defmodule NbFlop.Table do
  @moduledoc """
  Table DSL for building declarative data tables for Phoenix/Inertia.

  The Table DSL provides a "Table as Resource" pattern where backend is the single
  source of truth for table configuration, columns, filters, actions, and data.

  ## Usage

      defmodule MyAppWeb.Tables.UsersTable do
        use NbFlop.Table

        resource MyApp.Accounts.User
        repo MyApp.Repo

        config do
          name "users"
          default_sort {:name, :asc}
          default_per_page 25
          per_page_options [10, 25, 50, 100]
          sticky_header true
          searchable [:name, :email]
        end

        columns do
          text_column :name, sortable: true, searchable: true
          text_column :email, sortable: true
          badge_column :status, colors: %{"active" => :success, "inactive" => :danger}
          date_column :created_at, format: "MMM d, yyyy"
          action_column()
        end

        filters do
          text_filter :name, clauses: [:contains, :starts_with, :equals]
          set_filter :status, options: [{"active", "Active"}, {"inactive", "Inactive"}]
        end

        actions do
          action :edit, url: fn user -> "/users/\#{user.id}/edit" end, icon: "PencilIcon"
          action :delete,
            handle: fn user -> MyApp.Accounts.delete_user(user) end,
            icon: "TrashIcon",
            variant: :danger,
            confirmation: %{title: "Delete User", message: "Are you sure?"}
        end
      end

  ## Controller Usage

      def index(conn, params) do
        render_inertia(conn, :users_index,
          users: MyAppWeb.Tables.UsersTable.make(conn, params)
        )
      end

  ## Frontend Usage

      import { Table } from '@/components/flop';

      export default function UsersIndex({ users }) {
        return <Table resource={users} />;
      }
  """

  @doc """
  Callback to get the Ecto resource (schema or queryable).
  """
  @callback resource() :: Ecto.Queryable.t()

  @doc """
  Callback to get the Ecto repository.
  """
  @callback repo() :: module()

  @doc """
  Callback to get table configuration.
  """
  @callback config() :: NbFlop.Table.Config.t()

  @doc """
  Callback to get column definitions.
  """
  @callback columns() :: [NbFlop.Column.t()]

  @doc """
  Callback to get filter definitions.
  """
  @callback filters() :: [NbFlop.Filter.t()]

  @doc """
  Callback to get action definitions.
  """
  @callback actions() :: [NbFlop.Action.t()]

  @doc """
  Callback to get bulk action definitions.
  """
  @callback bulk_actions() :: [NbFlop.BulkAction.t()]

  @doc """
  Optional callback to determine if a row is selectable.
  Default is true for all rows.
  """
  @callback selectable?(row :: map(), conn :: Plug.Conn.t()) :: boolean()

  @doc """
  Optional callback for custom row transformation.
  """
  @callback transform_row(row :: map(), data :: map(), conn :: Plug.Conn.t()) :: map()

  @doc """
  Optional callback to get empty state configuration.
  """
  @callback empty_state() :: NbFlop.EmptyState.t() | nil

  @doc """
  Optional callback to get export definitions.
  """
  @callback exports() :: [NbFlop.Export.t()]

  @doc """
  Optional callback to get views configuration.
  """
  @callback views_config() :: NbFlop.ViewsConfig.t() | nil

  @optional_callbacks [
    selectable?: 2,
    transform_row: 3,
    empty_state: 0,
    exports: 0,
    views_config: 0
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour NbFlop.Table

      import NbFlop.Table.DSL

      Module.register_attribute(__MODULE__, :nb_flop_resource, accumulate: false)
      Module.register_attribute(__MODULE__, :nb_flop_repo, accumulate: false)
      Module.register_attribute(__MODULE__, :nb_flop_config, accumulate: false)
      Module.register_attribute(__MODULE__, :nb_flop_columns, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_filters, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_actions, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_bulk_actions, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_empty_state, accumulate: false)
      Module.register_attribute(__MODULE__, :nb_flop_exports, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_views_config, accumulate: false)

      @before_compile NbFlop.Table.Compiler

      # Marker function to identify valid table modules
      def __nb_flop_table__, do: true
    end
  end
end
