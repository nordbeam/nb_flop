defmodule NbFlop.Table.DSL.Config do
  @moduledoc """
  DSL macros for table configuration.
  """

  defmacro name(value) do
    quote do
      @nb_flop_config_builder Map.put(@nb_flop_config_builder, :name, unquote(value))
    end
  end

  defmacro default_sort(field_direction) do
    quote do
      @nb_flop_config_builder Map.put(
                                @nb_flop_config_builder,
                                :default_sort,
                                unquote(field_direction)
                              )
    end
  end

  defmacro default_per_page(value) do
    quote do
      @nb_flop_config_builder Map.put(@nb_flop_config_builder, :default_per_page, unquote(value))
    end
  end

  defmacro per_page_options(list) do
    quote do
      @nb_flop_config_builder Map.put(@nb_flop_config_builder, :per_page_options, unquote(list))
    end
  end

  defmacro sticky_header(value) do
    quote do
      @nb_flop_config_builder Map.put(@nb_flop_config_builder, :sticky_header, unquote(value))
    end
  end

  defmacro searchable(fields) do
    quote do
      @nb_flop_config_builder Map.put(@nb_flop_config_builder, :searchable, unquote(fields))
    end
  end

  defmacro search_placeholder(text) do
    quote do
      @nb_flop_config_builder Map.put(@nb_flop_config_builder, :search_placeholder, unquote(text))
    end
  end
end
