defmodule NbFlop.ViewsConfig do
  @moduledoc """
  Configuration for saved table views.

  Views allow users to save and restore table states (filters, sorting, columns).
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          scope_user: boolean(),
          user_resolver: (Plug.Conn.t() -> String.t() | nil) | nil,
          attributes: (Plug.Conn.t() -> map()) | nil,
          scope_table_name: String.t() | nil
        }

  defstruct [
    :user_resolver,
    :attributes,
    :scope_table_name,
    enabled: false,
    scope_user: false
  ]

  @doc """
  Creates a new ViewsConfig struct.

  ## Options

    * `:enabled` - Enable saved views feature
    * `:scope_user` - Each user sees their own views
    * `:user_resolver` - Function to get user ID from conn
    * `:attributes` - Function to get additional attributes (e.g., tenant_id)
    * `:scope_table_name` - Custom table name for scoping
  """
  def new(opts) when is_list(opts) do
    %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
      scope_user: Keyword.get(opts, :scope_user, false),
      user_resolver: Keyword.get(opts, :user_resolver),
      attributes: Keyword.get(opts, :attributes),
      scope_table_name: Keyword.get(opts, :scope_table_name)
    }
  end
end
