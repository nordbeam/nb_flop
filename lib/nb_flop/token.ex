defmodule NbFlop.Token do
  @moduledoc """
  Token generation and verification for action authentication.

  Uses Phoenix.Token to create signed tokens that identify which table module
  should handle an action request.
  """

  @salt "nb_flop_action_v1"
  # 24 hours
  @default_max_age 86_400

  @doc """
  Signs a token for the given table module.

  ## Options

    * `:context` - Additional context to include in the token
  """
  def sign(endpoint, table_module, opts \\ []) do
    context = Keyword.get(opts, :context, %{})

    data = %{
      table: Module.split(table_module) |> Enum.join("."),
      context: context,
      issued_at: System.system_time(:second)
    }

    Phoenix.Token.sign(endpoint, @salt, data)
  end

  @doc """
  Verifies a token and extracts the table module.

  Returns `{:ok, %{table: module, context: map}}` or `{:error, reason}`.

  ## Options

    * `:max_age` - Maximum token age in seconds (default: 24 hours)
  """
  def verify(endpoint, token, opts \\ []) do
    max_age = Keyword.get(opts, :max_age, @default_max_age)

    case Phoenix.Token.verify(endpoint, @salt, token, max_age: max_age) do
      {:ok, %{table: table_string} = data} ->
        table_module = Module.concat([table_string])

        # Verify the module exists and is a valid table
        if valid_table_module?(table_module) do
          {:ok, %{data | table: table_module}}
        else
          {:error, :invalid_table}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a module is a valid NbFlop.Table module.
  """
  def valid_table_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__nb_flop_table__, 0)
  end
end
