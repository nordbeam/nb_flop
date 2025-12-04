defmodule NbFlop.BulkAction do
  @moduledoc """
  Bulk action definition struct for NbFlop tables.

  Bulk actions operate on multiple selected rows at once.
  """

  @type t :: %__MODULE__{
          name: atom(),
          label: String.t(),
          icon: String.t() | nil,
          variant: NbFlop.Action.variant(),
          handle: ([map()] -> :ok | {:ok, String.t()} | {:error, String.t()}) | nil,
          confirmation: NbFlop.Confirmation.t() | nil,
          authorize: (Plug.Conn.t() -> boolean()) | nil,
          chunk_size: pos_integer(),
          before: ([map()] -> :ok | {:error, String.t()}) | nil,
          after: ([map()] -> :ok) | nil,
          frontend: boolean()
        }

  defstruct [
    :name,
    :label,
    :icon,
    :handle,
    :confirmation,
    :authorize,
    :before,
    :after,
    variant: :default,
    chunk_size: 100,
    frontend: false
  ]

  @doc """
  Creates a new BulkAction struct.

  ## Options

    * `:label` - Action button label
    * `:icon` - Icon name for frontend
    * `:variant` - Style variant (:default, :primary, :danger, etc.)
    * `:handle` - Function receiving list of rows, performs action
    * `:confirmation` - Confirmation dialog configuration
    * `:authorize` - Function to check if user can execute action
    * `:chunk_size` - Process rows in chunks of this size (default 100)
    * `:before` - Function called before processing (validation)
    * `:after` - Function called after processing
    * `:frontend` - If true, action is handled by frontend only
  """
  @valid_opts [
    :label,
    :icon,
    :variant,
    :handle,
    :confirmation,
    :authorize,
    :chunk_size,
    :before,
    :after,
    :frontend
  ]

  def new(name, opts \\ []) do
    validate_opts!(name, opts)
    label = Keyword.get(opts, :label, humanize(name))

    %__MODULE__{
      name: name,
      label: label,
      icon: Keyword.get(opts, :icon),
      variant: Keyword.get(opts, :variant, :default),
      handle: Keyword.get(opts, :handle),
      confirmation: build_confirmation(Keyword.get(opts, :confirmation)),
      authorize: Keyword.get(opts, :authorize),
      chunk_size: Keyword.get(opts, :chunk_size, 100),
      before: Keyword.get(opts, :before),
      after: Keyword.get(opts, :after),
      frontend: Keyword.get(opts, :frontend, false)
    }
  end

  defp validate_opts!(name, opts) do
    invalid_keys = Keyword.keys(opts) -- @valid_opts

    if invalid_keys != [] do
      valid_opts_str = Enum.map_join(@valid_opts, ", ", &inspect/1)

      raise ArgumentError, """
      Invalid option(s) #{inspect(invalid_keys)} for bulk_action #{inspect(name)}.

      Valid options are: #{valid_opts_str}
      """
    end
  end

  # Private helpers

  defp humanize(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp build_confirmation(nil), do: nil
  defp build_confirmation(%NbFlop.Confirmation{} = conf), do: conf
  defp build_confirmation(opts) when is_map(opts), do: NbFlop.Confirmation.new(opts)
  defp build_confirmation(opts) when is_list(opts), do: NbFlop.Confirmation.new(Map.new(opts))
end
