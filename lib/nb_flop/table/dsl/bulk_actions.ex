defmodule NbFlop.Table.DSL.BulkActions do
  @moduledoc """
  DSL macros for defining table bulk actions.
  """

  @doc """
  Defines a bulk action for multiple row operations.

  ## Options

    * `:label` - Action button label
    * `:icon` - Icon name for frontend
    * `:variant` - Style variant (:default, :primary, :danger, etc.)
    * `:handle` - Function receiving list of rows, performs action
    * `:confirmation` - Map with confirmation dialog config
    * `:authorize` - Function to check if user can execute action
    * `:chunk_size` - Process rows in chunks of this size
    * `:before` - Function called before processing
    * `:after` - Function called after processing
    * `:frontend` - If true, action is handled by frontend only

  ## Examples

      # Delete multiple users
      bulk_action :delete_selected,
        handle: fn users -> Enum.each(users, &MyApp.Accounts.delete_user/1) end,
        confirmation: %{
          title: "Delete Users",
          message: "Are you sure you want to delete {count} users?"
        }

      # Frontend-only action (triggers export)
      bulk_action :export_selected,
        frontend: true
  """
  defmacro bulk_action(name, opts \\ []) do
    # Store the AST of the options, not the evaluated result
    # This allows anonymous functions to be compiled properly
    quote do
      @nb_flop_bulk_actions {unquote(name), unquote(Macro.escape(opts, unquote: true))}
    end
  end
end
