defmodule NbFlop.EmptyState do
  @moduledoc """
  Empty state configuration for NbFlop tables.

  Displayed when table has no data.
  """

  @type t :: %__MODULE__{
          title: String.t(),
          message: String.t() | nil,
          icon: String.t() | nil,
          action: empty_state_action() | nil
        }

  @type empty_state_action :: %{
          label: String.t(),
          url: String.t(),
          variant: NbFlop.Action.variant()
        }

  defstruct [
    :title,
    :message,
    :icon,
    :action
  ]

  @doc """
  Creates a new EmptyState struct.
  """
  def new(opts) when is_list(opts) do
    %__MODULE__{
      title: Keyword.get(opts, :title, "No data found"),
      message: Keyword.get(opts, :message),
      icon: Keyword.get(opts, :icon),
      action: Keyword.get(opts, :action)
    }
  end
end
