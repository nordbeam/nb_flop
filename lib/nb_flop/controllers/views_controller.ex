defmodule NbFlop.ViewsController do
  @moduledoc """
  Controller for managing saved table views.

  Add these routes to your router using `NbFlop.Router.nb_flop_routes/1`:

      use NbFlop.Router

      scope "/" do
        pipe_through [:browser]
        nb_flop_routes()
      end

  Or manually:

      scope "/nb-flop", NbFlop do
        get "/views", ViewsController, :index
        post "/views", ViewsController, :create
        put "/views/:id", ViewsController, :update
        delete "/views/:id", ViewsController, :delete
        post "/views/:id/default", ViewsController, :set_default
      end
  """

  import Plug.Conn

  def init(opts), do: opts
  def call(conn, _opts), do: conn

  alias NbFlop.Views
  alias NbFlop.Views.SavedView

  @doc """
  Lists views for a table.

  Expects query params:
    * `token` - Signed table token
  """
  def index(conn, %{"token" => token}) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, user_id} <- get_user_id(table_module, conn) do
      config = table_module.config()
      views = Views.list_views(config.name, user_id)

      send_json(conn, 200, %{
        views: Enum.map(views, &SavedView.to_config/1)
      })
    else
      {:error, :invalid_table} ->
        send_json(conn, 400, %{error: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{error: "Token expired"})

      {:error, :views_disabled} ->
        send_json(conn, 400, %{error: "Views are not enabled for this table"})

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  def index(conn, _params) do
    send_json(conn, 400, %{error: "Missing required parameters"})
  end

  @doc """
  Creates a new saved view.

  Expects JSON body:
    * `token` - Signed table token
    * `name` - View name
    * `filters` - Optional filter configuration
    * `sort` - Optional sort configuration
    * `columns` - Optional column visibility/order
    * `perPage` - Optional page size
    * `isPublic` - Optional public flag
  """
  def create(conn, %{"token" => token, "name" => name} = params) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, user_id} <- get_user_id(table_module, conn),
         config <- table_module.config(),
         attrs <- build_create_attrs(config, user_id, name, params),
         {:ok, view} <- Views.create_view(attrs) do
      send_json(conn, 201, %{view: SavedView.to_config(view)})
    else
      {:error, :invalid_table} ->
        send_json(conn, 400, %{error: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{error: "Token expired"})

      {:error, :views_disabled} ->
        send_json(conn, 400, %{error: "Views are not enabled for this table"})

      {:error, %Ecto.Changeset{} = changeset} ->
        send_json(conn, 422, %{error: format_changeset_errors(changeset)})

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  def create(conn, _params) do
    send_json(conn, 400, %{error: "Missing required parameters"})
  end

  @doc """
  Updates an existing saved view.

  Expects JSON body:
    * `token` - Signed table token
    * `name` - Optional new view name
    * `filters` - Optional filter configuration
    * `sort` - Optional sort configuration
    * `columns` - Optional column visibility/order
    * `perPage` - Optional page size
    * `isPublic` - Optional public flag
  """
  def update(conn, %{"token" => token, "id" => id} = params) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, user_id} <- get_user_id(table_module, conn),
         view when not is_nil(view) <- Views.get_view(parse_id(id), user_id),
         attrs <- build_update_attrs(params),
         {:ok, updated_view} <- Views.update_view(view, attrs, user_id) do
      send_json(conn, 200, %{view: SavedView.to_config(updated_view)})
    else
      nil ->
        send_json(conn, 404, %{error: "View not found"})

      {:error, :invalid_table} ->
        send_json(conn, 400, %{error: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{error: "Token expired"})

      {:error, :views_disabled} ->
        send_json(conn, 400, %{error: "Views are not enabled for this table"})

      {:error, :unauthorized} ->
        send_json(conn, 403, %{error: "Not authorized to update this view"})

      {:error, %Ecto.Changeset{} = changeset} ->
        send_json(conn, 422, %{error: format_changeset_errors(changeset)})

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  def update(conn, _params) do
    send_json(conn, 400, %{error: "Missing required parameters"})
  end

  @doc """
  Deletes a saved view.
  """
  def delete(conn, %{"token" => token, "id" => id}) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, user_id} <- get_user_id(table_module, conn),
         view when not is_nil(view) <- Views.get_view(parse_id(id), user_id),
         :ok <- Views.delete_view(view, user_id) do
      send_json(conn, 200, %{success: true})
    else
      nil ->
        send_json(conn, 404, %{error: "View not found"})

      {:error, :invalid_table} ->
        send_json(conn, 400, %{error: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{error: "Token expired"})

      {:error, :views_disabled} ->
        send_json(conn, 400, %{error: "Views are not enabled for this table"})

      {:error, :unauthorized} ->
        send_json(conn, 403, %{error: "Not authorized to delete this view"})

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  def delete(conn, _params) do
    send_json(conn, 400, %{error: "Missing required parameters"})
  end

  @doc """
  Sets a view as the default.
  """
  def set_default(conn, %{"token" => token, "id" => id}) do
    endpoint = conn.private[:phoenix_endpoint]

    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(endpoint, token),
         {:ok, user_id} <- get_user_id(table_module, conn),
         view when not is_nil(view) <- Views.get_view(parse_id(id), user_id),
         {:ok, updated_view} <- Views.set_default(view, user_id) do
      send_json(conn, 200, %{view: SavedView.to_config(updated_view)})
    else
      nil ->
        send_json(conn, 404, %{error: "View not found"})

      {:error, :invalid_table} ->
        send_json(conn, 400, %{error: "Invalid table token"})

      {:error, :expired} ->
        send_json(conn, 401, %{error: "Token expired"})

      {:error, :views_disabled} ->
        send_json(conn, 400, %{error: "Views are not enabled for this table"})

      {:error, :unauthorized} ->
        send_json(conn, 403, %{error: "Not authorized to update this view"})

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  def set_default(conn, _params) do
    send_json(conn, 400, %{error: "Missing required parameters"})
  end

  # Private helpers

  defp get_user_id(table_module, conn) do
    views_config =
      if function_exported?(table_module, :views_config, 0) do
        table_module.views_config()
      else
        nil
      end

    cond do
      is_nil(views_config) or not views_config.enabled ->
        {:error, :views_disabled}

      views_config.scope_user and is_function(views_config.user_resolver) ->
        {:ok, views_config.user_resolver.(conn)}

      views_config.scope_user ->
        # Try common patterns
        cond do
          Map.has_key?(conn.assigns, :current_user) and not is_nil(conn.assigns.current_user) ->
            {:ok, conn.assigns.current_user.id}

          true ->
            {:ok, nil}
        end

      true ->
        {:ok, nil}
    end
  end

  defp build_create_attrs(config, user_id, name, params) do
    %{
      name: name,
      table_name: config.name,
      user_id: user_id,
      is_public: Map.get(params, "isPublic", false),
      filters: Map.get(params, "filters", %{}),
      sort: Map.get(params, "sort", %{}),
      columns: Map.get(params, "columns", []),
      per_page: Map.get(params, "perPage")
    }
  end

  defp build_update_attrs(params) do
    %{}
    |> maybe_put(:name, params["name"])
    |> maybe_put(:is_public, params["isPublic"])
    |> maybe_put(:filters, params["filters"])
    |> maybe_put(:sort, params["sort"])
    |> maybe_put(:columns, params["columns"])
    |> maybe_put(:per_page, params["perPage"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
  defp parse_id(id) when is_integer(id), do: id

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
    |> halt()
  end
end
