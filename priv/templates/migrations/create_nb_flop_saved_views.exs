defmodule <%= @repo %>.Migrations.CreateNbFlopSavedViews do
  use Ecto.Migration

  def change do
    create table(:nb_flop_saved_views) do
      add :name, :string, null: false
      add :table_name, :string, null: false
      add :user_id, references(<%= @users_table %>, on_delete: :delete_all)
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
  end
end
