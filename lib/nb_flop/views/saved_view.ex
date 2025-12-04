defmodule NbFlop.Views.SavedView do
  @moduledoc """
  Ecto schema for saved table views.

  Saved views allow users to save their table configurations including:
  - Filters
  - Sort settings
  - Column visibility and order
  - Custom name and sharing settings

  ## Schema

  The schema expects a table with the following columns:

      create table(:nb_flop_saved_views) do
        add :name, :string, null: false
        add :table_name, :string, null: false
        add :user_id, references(:users, on_delete: :delete_all)
        add :is_default, :boolean, default: false
        add :is_public, :boolean, default: false
        add :filters, :map, default: %{}
        add :sort, :map, default: %{}
        add :columns, {:array, :string}, default: []
        add :per_page, :integer

        timestamps()
      end

      create index(:nb_flop_saved_views, [:table_name])
      create index(:nb_flop_saved_views, [:user_id])
      create unique_index(:nb_flop_saved_views, [:user_id, :table_name, :name])

  ## Configuration

  Configure the schema in your application:

      config :nb_flop, :saved_views,
        schema: MyApp.NbFlopSavedView,
        repo: MyApp.Repo,
        user_association: :user,
        user_id_field: :user_id
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          table_name: String.t(),
          user_id: integer() | nil,
          is_default: boolean(),
          is_public: boolean(),
          filters: map(),
          sort: map(),
          columns: [String.t()],
          per_page: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "nb_flop_saved_views" do
    field(:name, :string)
    field(:table_name, :string)
    field(:user_id, :id)
    field(:is_default, :boolean, default: false)
    field(:is_public, :boolean, default: false)
    field(:filters, :map, default: %{})
    field(:sort, :map, default: %{})
    field(:columns, {:array, :string}, default: [])
    field(:per_page, :integer)

    timestamps()
  end

  @doc """
  Changeset for creating a new saved view.
  """
  @spec create_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(view \\ %__MODULE__{}, attrs) do
    view
    |> cast(attrs, [
      :name,
      :table_name,
      :user_id,
      :is_default,
      :is_public,
      :filters,
      :sort,
      :columns,
      :per_page
    ])
    |> validate_required([:name, :table_name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:table_name, min: 1, max: 100)
    |> validate_number(:per_page, greater_than: 0, less_than_or_equal_to: 1000)
  end

  @doc """
  Changeset for updating an existing saved view.
  """
  @spec update_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(view, attrs) do
    view
    |> cast(attrs, [:name, :is_default, :is_public, :filters, :sort, :columns, :per_page])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:per_page, greater_than: 0, less_than_or_equal_to: 1000)
  end

  @doc """
  Returns the view configuration as a map suitable for frontend consumption.
  """
  @spec to_config(t()) :: map()
  def to_config(%__MODULE__{} = view) do
    %{
      id: view.id,
      name: view.name,
      isDefault: view.is_default,
      isPublic: view.is_public,
      filters: view.filters,
      sort: view.sort,
      columns: view.columns,
      perPage: view.per_page
    }
  end
end
