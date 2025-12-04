defmodule NbFlop.Action do
  @moduledoc """
  Action definition struct for NbFlop tables.

  Actions can be either URL-based (navigation) or handler-based (execute callback).
  """

  @type variant :: :default | :primary | :secondary | :danger | :warning | :success

  @type t :: %__MODULE__{
          name: atom(),
          label: String.t(),
          icon: String.t() | nil,
          variant: variant(),
          url: (map() -> String.t()) | nil,
          handle: (map() -> :ok | {:ok, String.t()} | {:error, String.t()}) | nil,
          disabled: (map() -> boolean()) | (map(), Plug.Conn.t() -> boolean()) | nil,
          hidden: (map() -> boolean()) | (map(), Plug.Conn.t() -> boolean()) | nil,
          confirmation: NbFlop.Confirmation.t() | nil,
          authorize: (Plug.Conn.t() -> boolean()) | nil,
          success_message: String.t() | nil,
          error_message: String.t() | nil,
          frontend: boolean()
        }

  defstruct [
    :name,
    :label,
    :icon,
    :url,
    :handle,
    :disabled,
    :hidden,
    :confirmation,
    :authorize,
    :success_message,
    :error_message,
    variant: :default,
    frontend: false
  ]

  @doc """
  Creates a new Action struct.

  ## Options

    * `:label` - Action button label (defaults to humanized name)
    * `:icon` - Icon name for frontend
    * `:variant` - Style variant (:default, :primary, :danger, etc.)
    * `:url` - Function that receives row and returns URL string
    * `:handle` - Function that receives row and performs action
    * `:disabled` - Function to determine if action is disabled for a row
    * `:hidden` - Function to determine if action is hidden for a row
    * `:visible` - Alias for hidden with inverted logic (use one or the other, not both)
    * `:confirmation` - Confirmation dialog configuration
    * `:authorize` - Function to check if user can execute action
    * `:success_message` - Message shown on success
    * `:error_message` - Message shown on error
    * `:frontend` - If true, action is handled by frontend only
  """
  @valid_opts [
    :label,
    :icon,
    :variant,
    :url,
    :handle,
    :disabled,
    :hidden,
    :visible,
    :confirmation,
    :authorize,
    :success_message,
    :error_message,
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
      url: Keyword.get(opts, :url),
      handle: Keyword.get(opts, :handle),
      disabled: Keyword.get(opts, :disabled),
      hidden: resolve_hidden(opts),
      confirmation: build_confirmation(Keyword.get(opts, :confirmation)),
      authorize: Keyword.get(opts, :authorize),
      success_message: Keyword.get(opts, :success_message),
      error_message: Keyword.get(opts, :error_message),
      frontend: Keyword.get(opts, :frontend, false)
    }
  end

  # Resolve hidden from either :hidden or :visible (inverted)
  defp resolve_hidden(opts) do
    hidden = Keyword.get(opts, :hidden)
    visible = Keyword.get(opts, :visible)

    cond do
      hidden && visible ->
        raise ArgumentError,
              "Cannot specify both :hidden and :visible options. Use one or the other."

      visible ->
        # Invert the visible function to get hidden
        invert_visibility(visible)

      true ->
        hidden
    end
  end

  # Invert a visibility function (visible -> hidden)
  defp invert_visibility(visible_fn) when is_function(visible_fn, 1) do
    fn row -> not visible_fn.(row) end
  end

  defp invert_visibility(visible_fn) when is_function(visible_fn, 2) do
    fn row, conn -> not visible_fn.(row, conn) end
  end

  defp invert_visibility(nil), do: nil

  defp validate_opts!(name, opts) do
    invalid_keys = Keyword.keys(opts) -- @valid_opts

    if invalid_keys != [] do
      valid_opts_str = Enum.map_join(@valid_opts, ", ", &inspect/1)

      raise ArgumentError, """
      Invalid option(s) #{inspect(invalid_keys)} for action #{inspect(name)}.

      Valid options are: #{valid_opts_str}
      """
    end
  end

  @doc """
  Evaluates action state for a specific row.

  Returns a map with:
    * `:url` - The URL string or nil
    * `:disabled` - Boolean indicating if action is disabled
    * `:hidden` - Boolean indicating if action is hidden
  """
  def evaluate_for_row(%__MODULE__{} = action, row, conn \\ nil) do
    %{
      url: evaluate_url(action.url, row),
      disabled: evaluate_callback(action.disabled, row, conn),
      hidden: evaluate_callback(action.hidden, row, conn)
    }
  end

  @doc """
  Checks if the action is a URL-based action (navigation).
  """
  def url_action?(%__MODULE__{url: url}) when is_function(url), do: true
  def url_action?(_), do: false

  @doc """
  Checks if the action is a handler-based action.
  """
  def handler_action?(%__MODULE__{handle: handle}) when is_function(handle), do: true
  def handler_action?(_), do: false

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

  defp evaluate_url(nil, _row), do: nil
  defp evaluate_url(url_fn, row) when is_function(url_fn, 1), do: url_fn.(row)

  defp evaluate_callback(nil, _row, _conn), do: false
  defp evaluate_callback(callback, row, nil) when is_function(callback, 1), do: callback.(row)

  defp evaluate_callback(callback, row, conn) when is_function(callback, 2),
    do: callback.(row, conn)

  defp evaluate_callback(callback, row, _conn) when is_function(callback, 1), do: callback.(row)
end
