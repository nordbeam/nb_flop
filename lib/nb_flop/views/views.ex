defmodule NbFlop.Views do
  @moduledoc """
  Context module for managing saved table views.

  ## Configuration

  Configure the views context in your application:

      config :nb_flop, :views,
        repo: MyApp.Repo,
        schema: NbFlop.Views.SavedView,  # or your custom schema
        get_user_id: fn conn -> conn.assigns.current_user.id end

  ## Usage

      # List views for a table
      views = NbFlop.Views.list_views("users", user_id)

      # Create a view
      {:ok, view} = NbFlop.Views.create_view(%{
        name: "Active Users",
        table_name: "users",
        user_id: user_id,
        filters: %{status: "active"}
      })

      # Update a view
      {:ok, view} = NbFlop.Views.update_view(view, %{name: "New Name"})

      # Delete a view
      :ok = NbFlop.Views.delete_view(view)

      # Set as default
      {:ok, view} = NbFlop.Views.set_default(view)
  """

  import Ecto.Query

  alias NbFlop.Views.SavedView

  @doc """
  Returns the configured repo for views.
  """
  @spec repo() :: module()
  def repo do
    Application.get_env(:nb_flop, :views, [])
    |> Keyword.get(:repo)
    |> case do
      nil ->
        raise "NbFlop views repo not configured. Set config :nb_flop, :views, repo: MyApp.Repo"

      repo ->
        repo
    end
  end

  @doc """
  Returns the configured schema for views.
  """
  @spec schema() :: module()
  def schema do
    Application.get_env(:nb_flop, :views, [])
    |> Keyword.get(:schema, SavedView)
  end

  @doc """
  Lists views for a table that are visible to the given user.

  Returns views that are:
  - Owned by the user
  - Public views from other users
  """
  @spec list_views(String.t(), integer() | nil) :: [SavedView.t()]
  def list_views(table_name, user_id) do
    schema_mod = schema()

    query =
      from(v in schema_mod,
        where: v.table_name == ^table_name,
        where: v.user_id == ^user_id or v.is_public == true,
        order_by: [desc: v.is_default, asc: v.name]
      )

    repo().all(query)
  end

  @doc """
  Gets a single view by ID.

  Returns nil if view doesn't exist or user doesn't have access.
  """
  @spec get_view(integer(), integer() | nil) :: SavedView.t() | nil
  def get_view(id, user_id) do
    schema_mod = schema()

    query =
      from(v in schema_mod,
        where: v.id == ^id,
        where: v.user_id == ^user_id or v.is_public == true
      )

    repo().one(query)
  end

  @doc """
  Gets the default view for a table and user.
  """
  @spec get_default_view(String.t(), integer() | nil) :: SavedView.t() | nil
  def get_default_view(table_name, user_id) do
    schema_mod = schema()

    query =
      from(v in schema_mod,
        where: v.table_name == ^table_name,
        where: v.user_id == ^user_id,
        where: v.is_default == true,
        limit: 1
      )

    repo().one(query)
  end

  @doc """
  Creates a new saved view.
  """
  @spec create_view(map()) :: {:ok, SavedView.t()} | {:error, Ecto.Changeset.t()}
  def create_view(attrs) do
    schema_mod = schema()

    schema_mod
    |> struct()
    |> schema_mod.create_changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing saved view.

  Only the owner can update a view.
  """
  @spec update_view(SavedView.t(), map(), integer() | nil) ::
          {:ok, SavedView.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_view(view, attrs, user_id) do
    if view.user_id == user_id do
      schema_mod = schema()

      view
      |> schema_mod.update_changeset(attrs)
      |> repo().update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a saved view.

  Only the owner can delete a view.
  """
  @spec delete_view(SavedView.t(), integer() | nil) :: :ok | {:error, :unauthorized}
  def delete_view(view, user_id) do
    if view.user_id == user_id do
      repo().delete(view)
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Sets a view as the default for its table.

  Unsets any existing default view for the same table/user.
  """
  @spec set_default(SavedView.t(), integer() | nil) ::
          {:ok, SavedView.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def set_default(view, user_id) do
    if view.user_id == user_id do
      schema_mod = schema()

      repo().transaction(fn ->
        # Unset existing defaults for this table/user
        from(v in schema_mod,
          where: v.table_name == ^view.table_name,
          where: v.user_id == ^user_id,
          where: v.is_default == true
        )
        |> repo().update_all(set: [is_default: false])

        # Set this view as default
        view
        |> Ecto.Changeset.change(is_default: true)
        |> repo().update!()
      end)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Unsets the default view for a table.
  """
  @spec unset_default(String.t(), integer() | nil) :: :ok
  def unset_default(table_name, user_id) do
    schema_mod = schema()

    from(v in schema_mod,
      where: v.table_name == ^table_name,
      where: v.user_id == ^user_id,
      where: v.is_default == true
    )
    |> repo().update_all(set: [is_default: false])

    :ok
  end
end
