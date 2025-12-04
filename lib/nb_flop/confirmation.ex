defmodule NbFlop.Confirmation do
  @moduledoc """
  Confirmation dialog configuration for destructive actions.
  """

  @type t :: %__MODULE__{
          title: String.t(),
          message: String.t(),
          confirm_button: String.t(),
          cancel_button: String.t(),
          icon: String.t() | nil,
          variant: :default | :primary | :secondary | :danger | :warning | :success
        }

  defstruct [
    :title,
    :message,
    :icon,
    confirm_button: "Confirm",
    cancel_button: "Cancel",
    variant: :danger
  ]

  @doc """
  Creates a new Confirmation struct.
  """
  def new(opts) when is_map(opts) do
    %__MODULE__{
      title: Map.get(opts, :title, "Confirm Action"),
      message: Map.get(opts, :message, "Are you sure you want to perform this action?"),
      confirm_button: Map.get(opts, :confirm_button, "Confirm"),
      cancel_button: Map.get(opts, :cancel_button, "Cancel"),
      icon: Map.get(opts, :icon),
      variant: Map.get(opts, :variant, :danger)
    }
  end
end
