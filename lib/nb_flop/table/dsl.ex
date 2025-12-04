defmodule NbFlop.Table.DSL do
  @moduledoc """
  DSL macros for defining NbFlop tables.

  This module is automatically imported when you `use NbFlop.Table`.
  """

  @doc """
  Sets the Ecto resource (schema or queryable) for this table.

  ## Example

      resource MyApp.Accounts.User
  """
  defmacro resource(module) do
    quote do
      @nb_flop_resource unquote(module)
    end
  end

  @doc """
  Sets the Ecto repository for this table.

  ## Example

      repo MyApp.Repo
  """
  defmacro repo(module) do
    quote do
      @nb_flop_repo unquote(module)
    end
  end

  @doc """
  Defines table configuration.

  ## Example

      config do
        name "users"
        default_sort {:name, :asc}
        default_per_page 25
        per_page_options [10, 25, 50, 100]
        sticky_header true
        searchable [:name, :email]
      end
  """
  defmacro config(do: block) do
    quote do
      import NbFlop.Table.DSL.Config
      @nb_flop_config_builder %{}
      unquote(block)
      @nb_flop_config NbFlop.Table.Config.new(Map.to_list(@nb_flop_config_builder))
    end
  end

  @doc """
  Defines columns for this table.

  ## Example

      columns do
        text_column :name, sortable: true
        badge_column :status, colors: %{"active" => :success}
      end
  """
  defmacro columns(do: block) do
    quote do
      import NbFlop.Table.DSL.Columns
      unquote(block)
    end
  end

  @doc """
  Defines filters for this table.

  ## Example

      filters do
        text_filter :name, clauses: [:contains, :starts_with]
        set_filter :status, options: [{"active", "Active"}]
      end
  """
  defmacro filters(do: block) do
    quote do
      import NbFlop.Table.DSL.Filters
      unquote(block)
    end
  end

  @doc """
  Defines row actions for this table.

  ## Example

      actions do
        action :edit, url: fn user -> "/users/\#{user.id}/edit" end
        action :delete, handle: fn user -> delete(user) end
      end
  """
  defmacro actions(do: block) do
    quote do
      import NbFlop.Table.DSL.Actions
      unquote(block)
    end
  end

  @doc """
  Defines bulk actions for this table.

  ## Example

      bulk_actions do
        bulk_action :delete_selected, handle: fn users -> Enum.each(users, &delete/1) end
      end
  """
  defmacro bulk_actions(do: block) do
    quote do
      import NbFlop.Table.DSL.BulkActions
      unquote(block)
    end
  end

  @doc """
  Defines empty state configuration.

  ## Example

      empty_state do
        title "No users found"
        message "Get started by creating your first user."
        icon "UsersIcon"
        action_button "Create User", ~p"/users/new", variant: :primary
      end
  """
  defmacro empty_state(do: block) do
    quote do
      import NbFlop.Table.DSL.EmptyState
      @nb_flop_empty_state_builder %{}
      unquote(block)
      @nb_flop_empty_state NbFlop.EmptyState.new(Map.to_list(@nb_flop_empty_state_builder))
    end
  end

  @doc """
  Defines exports for this table.

  ## Example

      exports do
        export :csv, columns: [:name, :email, :status]
        export :excel
      end
  """
  defmacro exports(do: block) do
    quote do
      import NbFlop.Table.DSL.Exports
      unquote(block)
    end
  end

  @doc """
  Defines views (saved table states) configuration.

  ## Example

      views do
        enabled true
        scope_user true
        user_resolver fn conn -> conn.assigns.current_user.id end
      end
  """
  defmacro views(do: block) do
    quote do
      import NbFlop.Table.DSL.Views
      @nb_flop_views_config_builder %{}
      unquote(block)
      @nb_flop_views_config NbFlop.ViewsConfig.new(Map.to_list(@nb_flop_views_config_builder))
    end
  end
end
