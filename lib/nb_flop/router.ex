defmodule NbFlop.Router do
  @moduledoc """
  Router macros for NbFlop action endpoints.

  ## Usage

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use NbFlop.Router

        scope "/" do
          pipe_through [:browser]

          # Add NbFlop routes
          nb_flop_routes()
        end
      end

  Or using import:

      import NbFlop.Router

  **Note**: When using `use NbFlop.Router`, the module automatically imports all
  macros. When using `import NbFlop.Router`, you get the same behavior.

  This adds the following routes:
    * `POST /nb-flop/action` - Execute row action
    * `POST /nb-flop/bulk-action` - Execute bulk action
    * `GET /nb-flop/export` - Export data
    * `GET /nb-flop/views` - List saved views
    * `POST /nb-flop/views` - Create saved view
    * `PUT /nb-flop/views/:id` - Update saved view
    * `DELETE /nb-flop/views/:id` - Delete saved view
    * `POST /nb-flop/views/:id/default` - Set default view

  ## Options

    * `:path` - Base path for routes (default: "/nb-flop")
    * `:only` - Only include specific routes (e.g., `[:action, :bulk_action]`)
    * `:except` - Exclude specific routes
  """

  defmacro __using__(_opts) do
    quote do
      import NbFlop.Router
    end
  end

  defmacro nb_flop_routes(opts \\ []) do
    path = Keyword.get(opts, :path, "/nb-flop")
    only = Keyword.get(opts, :only)
    except = Keyword.get(opts, :except, [])

    routes =
      [
        {:action, quote(do: post(unquote("#{path}/action"), NbFlop.ActionController, :execute))},
        {:bulk_action,
         quote(do: post(unquote("#{path}/bulk-action"), NbFlop.ActionController, :execute_bulk))},
        {:export, quote(do: get(unquote("#{path}/export"), NbFlop.ExportController, :export))},
        {:views_index, quote(do: get(unquote("#{path}/views"), NbFlop.ViewsController, :index))},
        {:views_create,
         quote(do: post(unquote("#{path}/views"), NbFlop.ViewsController, :create))},
        {:views_update,
         quote(do: put(unquote("#{path}/views/:id"), NbFlop.ViewsController, :update))},
        {:views_delete,
         quote(do: delete(unquote("#{path}/views/:id"), NbFlop.ViewsController, :delete))},
        {:views_default,
         quote(
           do: post(unquote("#{path}/views/:id/default"), NbFlop.ViewsController, :set_default)
         )}
      ]
      |> Enum.filter(fn {name, _} ->
        included? = is_nil(only) or name in only
        not_excluded? = name not in except
        included? and not_excluded?
      end)
      |> Enum.map(fn {_, route} -> route end)

    quote do
      (unquote_splicing(routes))
    end
  end

  @doc """
  Minimal routes for action execution only.

  Equivalent to `nb_flop_routes(only: [:action, :bulk_action])`
  """
  defmacro nb_flop_action_routes(opts \\ []) do
    quote do
      NbFlop.Router.nb_flop_routes(unquote(Keyword.put(opts, :only, [:action, :bulk_action])))
    end
  end
end
