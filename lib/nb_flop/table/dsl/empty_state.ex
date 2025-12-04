defmodule NbFlop.Table.DSL.EmptyState do
  @moduledoc """
  DSL macros for configuring table empty state.
  """

  defmacro title(text) do
    quote do
      @nb_flop_empty_state_builder Map.put(@nb_flop_empty_state_builder, :title, unquote(text))
    end
  end

  defmacro message(text) do
    quote do
      @nb_flop_empty_state_builder Map.put(@nb_flop_empty_state_builder, :message, unquote(text))
    end
  end

  defmacro icon(name) do
    quote do
      @nb_flop_empty_state_builder Map.put(@nb_flop_empty_state_builder, :icon, unquote(name))
    end
  end

  defmacro action_button(label, url, opts \\ []) do
    quote do
      action = %{
        label: unquote(label),
        url: unquote(url),
        variant: Keyword.get(unquote(opts), :variant, :primary)
      }

      @nb_flop_empty_state_builder Map.put(@nb_flop_empty_state_builder, :action, action)
    end
  end
end
