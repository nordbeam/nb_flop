defmodule NbFlop.Table.DSL.Actions do
  @moduledoc """
  DSL macros for defining table row actions.
  """

  @doc """
  Defines a row action.

  ## Options

    * `:label` - Action button label
    * `:icon` - Icon name for frontend
    * `:variant` - Style variant (:default, :primary, :danger, etc.)
    * `:url` - Function receiving row, returns URL string
    * `:handle` - Function receiving row, performs action
    * `:disabled` - Function to check if action is disabled for a row
    * `:hidden` - Function to check if action is hidden for a row
    * `:visible` - Alias for hidden with inverted logic (use one or the other)
    * `:confirmation` - Map with confirmation dialog config
    * `:authorize` - Function to check if user can execute action
    * `:success_message` - Message shown on success
    * `:error_message` - Message shown on error
    * `:frontend` - If true, action is handled by frontend only

  ## Examples

      # URL action (navigation)
      action :edit, url: fn user -> "/users/\#{user.id}/edit" end, icon: "PencilIcon"

      # Handler action with visible (more intuitive than hidden)
      action :delete,
        handle: fn user -> MyApp.Accounts.delete_user(user) end,
        icon: "TrashIcon",
        variant: :danger,
        visible: fn user -> is_nil(user.deleted_at) end,
        confirmation: %{
          title: "Delete User",
          message: "Are you sure you want to delete this user?"
        }

      # Restore action - only visible when deleted
      action :restore,
        handle: fn user -> MyApp.Accounts.restore_user(user) end,
        icon: "ArrowPathIcon",
        visible: fn user -> not is_nil(user.deleted_at) end

      # Conditional action with conn access
      action :archive,
        handle: fn user -> MyApp.Accounts.archive_user(user) end,
        disabled: fn user -> user.archived end,
        visible: fn user, conn -> admin?(conn) end
  """
  defmacro action(name, opts \\ []) do
    # Store the AST of the options, not the evaluated result
    # This allows anonymous functions to be compiled properly
    quote do
      @nb_flop_actions {unquote(name), unquote(Macro.escape(opts, unquote: true))}
    end
  end
end
