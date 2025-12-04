defmodule NbFlop.Table.DSL.Views do
  @moduledoc """
  DSL macros for configuring saved table views.
  """

  defmacro enabled(value) do
    quote do
      @nb_flop_views_config_builder Map.put(
                                      @nb_flop_views_config_builder,
                                      :enabled,
                                      unquote(value)
                                    )
    end
  end

  defmacro scope_user(value) do
    quote do
      @nb_flop_views_config_builder Map.put(
                                      @nb_flop_views_config_builder,
                                      :scope_user,
                                      unquote(value)
                                    )
    end
  end

  defmacro user_resolver(func) do
    quote do
      @nb_flop_views_config_builder Map.put(
                                      @nb_flop_views_config_builder,
                                      :user_resolver,
                                      unquote(func)
                                    )
    end
  end

  defmacro attributes(func) do
    quote do
      @nb_flop_views_config_builder Map.put(
                                      @nb_flop_views_config_builder,
                                      :attributes,
                                      unquote(func)
                                    )
    end
  end

  defmacro scope_table_name(name) do
    quote do
      @nb_flop_views_config_builder Map.put(
                                      @nb_flop_views_config_builder,
                                      :scope_table_name,
                                      unquote(name)
                                    )
    end
  end
end
