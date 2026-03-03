defmodule NbFlop.Rpc do
  @moduledoc """
  Helpers for using NbFlop tables in NbRpc procedures.

  ## Usage

      defmodule MyAppWeb.Procedures.Users do
        use NbRpc.Procedure

        alias MyAppWeb.Tables.UsersTable

        query :table,
          input: NbFlop.Rpc.input_spec(),
          output: NbFlop.Serializers.TableResourceSerializer do

          NbFlop.Rpc.build(UsersTable, ctx, input,
            endpoint: MyAppWeb.Endpoint
          )
        end

        mutation :table_action,
          input: NbFlop.Rpc.action_input_spec() do

          NbFlop.Rpc.execute_action(UsersTable, ctx, input)
        end

        mutation :table_bulk_action,
          input: NbFlop.Rpc.bulk_action_input_spec() do

          NbFlop.Rpc.execute_bulk_action(UsersTable, ctx, input)
        end
      end
  """

  @doc """
  Returns the standard input spec for table query procedures.

  Fields:
  - `page` — page number (integer, optional)
  - `page_size` — items per page (integer, optional)
  - `order_by` — sort fields (list of strings, optional)
  - `order_directions` — sort directions (list of "asc"/"desc", optional)
  - `filters` — Flop filters (list of `%{field, op, value}`, optional)
  - `search` — full-text search query (string, optional)
  """
  def input_spec do
    %{
      page: {:integer, optional: true},
      page_size: {:integer, optional: true},
      order_by: {:any, optional: true},
      order_directions: {:any, optional: true},
      filters: {:any, optional: true},
      search: {:string, optional: true}
    }
  end

  @doc """
  Returns the input spec for single row action execution.
  """
  def action_input_spec do
    %{
      action: :string,
      id: :any
    }
  end

  @doc """
  Returns the input spec for bulk action execution.
  """
  def bulk_action_input_spec do
    %{
      action: :string,
      mode: :string,
      ids: {:any, optional: true},
      filters: {:any, optional: true}
    }
  end

  @doc """
  Builds a table resource for an RPC response.

  Converts structured RPC input to the params format expected by Builder,
  then calls `Builder.build/4`.

  ## Options

    * `:endpoint` — Phoenix endpoint for token generation (required for actions)
    * `:query` — Custom base query (for scoping, e.g. multi-tenant)
    * `:preload` — Associations to preload
    * `:as` — Override table name
    * `:search_op` — Flop operator for compound field search (default: `:ilike_and`).
      Use `:like_and` for SQLite. Can also be set globally via
      `config :nb_flop, search_op: :like_and`.
  """
  def build(table_module, ctx, input, opts \\ []) do
    search_op =
      Keyword.get(opts, :search_op) ||
        Application.get_env(:nb_flop, :search_op, :ilike_and)

    params = input_to_params(input)
    params = apply_search_filter(params, input[:search], search_op)
    opts = ensure_endpoint(opts, ctx)

    result =
      table_module
      |> NbFlop.Table.Builder.build(ctx, params, opts)
      |> normalize_for_rpc()

    # Track search in state so frontend can display current search value
    if input[:search] do
      put_in(result, [:state, :search], input[:search])
    else
      result
    end
  end

  @doc """
  Executes a single row action via RPC.

  Returns `%{success: true, message: "..."}` on success or raises an NbRpc error.
  """
  def execute_action(table_module, ctx, input) do
    action_name = input.action
    id = input.id

    with {:ok, action} <- find_action(table_module, action_name),
         :ok <- authorize(action.authorize, ctx),
         {:ok, row} <- load_row(table_module, id),
         :ok <- check_not_disabled(action, row, ctx) do
      case do_execute_action(action, row) do
        {:redirect, url} ->
          %{success: true, redirect: url}

        :ok ->
          %{success: true, message: action.success_message || "Action completed"}

        {:ok, msg} when is_binary(msg) ->
          %{success: true, message: msg}

        {:ok, _} ->
          %{success: true, message: action.success_message || "Action completed"}

        {:error, reason} ->
          raise_error(:internal, to_string(reason))
      end
    else
      {:error, reason} -> raise_error(reason)
    end
  end

  @doc """
  Executes a bulk action via RPC.

  Returns `%{success: true, count: N}` on success or raises an NbRpc error.
  """
  def execute_bulk_action(table_module, ctx, input) do
    action_name = input.action
    mode = input.mode
    ids = input[:ids] || []
    filters = input[:filters] || []

    with {:ok, action} <- find_bulk_action(table_module, action_name),
         :ok <- authorize(action.authorize, ctx),
         {:ok, rows} <- load_selected_rows(table_module, mode, ids, filters),
         :ok <- run_callback(action.before, rows) do
      result = execute_in_chunks(action.handle, rows, action.chunk_size)
      run_callback(action.after, rows)

      case result do
        :ok ->
          %{success: true, count: length(rows)}

        {:ok, message} when is_binary(message) ->
          %{success: true, count: length(rows), message: message}

        {:error, reason} ->
          raise_error(:internal, to_string(reason))
      end
    else
      {:error, reason} -> raise_error(reason)
    end
  end

  # -- Private: Input conversion --

  defp input_to_params(input) do
    params = %{}

    params = put_if(params, "page", input[:page])
    params = put_if(params, "page_size", input[:page_size])

    # Sort: convert list format to what Builder expects
    params =
      case input[:order_by] do
        [field | _] = fields when is_binary(field) ->
          direction =
            case input[:order_directions] do
              [dir | _] -> dir
              _ -> "asc"
            end

          params
          |> Map.put("order_by", fields)
          |> Map.put("order_directions", input[:order_directions] || [direction])

        field when is_binary(field) ->
          direction =
            case input[:order_directions] do
              [dir | _] -> dir
              dir when is_binary(dir) -> dir
              _ -> "asc"
            end

          Map.put(params, "sort", "#{field}:#{direction}")

        _ ->
          params
      end

    # Filters: convert atom-keyed maps to string-keyed for Builder
    case input[:filters] do
      filters when is_list(filters) and length(filters) > 0 ->
        converted =
          Enum.map(filters, fn f ->
            %{
              "field" => to_string(f[:field] || f["field"]),
              "op" => to_string(f[:op] || f["op"] || "=="),
              "value" => f[:value] || f["value"]
            }
          end)

        Map.put(params, "filters", converted)

      _ ->
        params
    end
  end

  # Convert search input into a Flop filter on the :search compound field.
  # The schema must declare compound_fields: [search: [...fields...]] in
  # its @derive Flop.Schema adapter_opts for this to work.
  # Default operator is :ilike_and (PostgreSQL). Use :like_and for SQLite.
  defp apply_search_filter(params, nil, _op), do: params
  defp apply_search_filter(params, "", _op), do: params

  defp apply_search_filter(params, search, op) do
    search_filter = %{"field" => "search", "op" => to_string(op), "value" => search}
    existing_filters = Map.get(params, "filters", [])
    Map.put(params, "filters", existing_filters ++ [search_filter])
  end

  # Normalize Builder output for RPC serialization.
  # Builder returns DateTime structs in row data — convert to ISO 8601 strings
  # since NbSerializer's :any type can't handle struct values.
  defp normalize_for_rpc(%{data: data} = resource) do
    %{resource | data: Enum.map(data, &normalize_row/1)}
  end

  defp normalize_row(row) when is_map(row) do
    Map.new(row, fn {k, v} -> {k, normalize_value(v)} end)
  end

  defp normalize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp normalize_value(%Date{} = d), do: Date.to_iso8601(d)
  defp normalize_value(%{__struct__: _} = struct), do: Map.from_struct(struct)
  defp normalize_value(v), do: v

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp ensure_endpoint(opts, ctx) do
    if Keyword.has_key?(opts, :endpoint) do
      opts
    else
      endpoint =
        get_in_safe(ctx, :assigns, :endpoint) ||
          Application.get_env(:nb_flop, :endpoint)

      if endpoint, do: Keyword.put(opts, :endpoint, endpoint), else: opts
    end
  end

  defp get_in_safe(ctx, :assigns, key) do
    case ctx do
      %{assigns: assigns} when is_map(assigns) -> Map.get(assigns, key)
      _ -> nil
    end
  end

  # -- Private: Action helpers --

  defp find_action(table_module, action_name) do
    action_atom =
      if is_binary(action_name), do: String.to_existing_atom(action_name), else: action_name

    case Enum.find(table_module.actions(), &(&1.name == action_atom)) do
      nil -> {:error, :not_found}
      action -> {:ok, action}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  defp find_bulk_action(table_module, action_name) do
    action_atom =
      if is_binary(action_name), do: String.to_existing_atom(action_name), else: action_name

    case Enum.find(table_module.bulk_actions(), &(&1.name == action_atom)) do
      nil -> {:error, :not_found}
      action -> {:ok, action}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  defp authorize(nil, _ctx), do: :ok

  defp authorize(authorize_fn, ctx) do
    if authorize_fn.(ctx), do: :ok, else: {:error, :forbidden}
  end

  defp load_row(table_module, id) do
    repo = table_module.repo()
    resource = table_module.resource()

    case repo.get(resource, id) do
      nil -> {:error, :not_found}
      row -> {:ok, row}
    end
  end

  defp check_not_disabled(%{disabled: nil}, _row, _ctx), do: :ok

  defp check_not_disabled(%{disabled: disabled}, row, ctx) do
    result =
      case Function.info(disabled, :arity) do
        {:arity, 1} -> disabled.(row)
        {:arity, 2} -> disabled.(row, ctx)
      end

    if result, do: {:error, :forbidden}, else: :ok
  end

  defp do_execute_action(%{handle: nil, url: url}, row) when is_function(url) do
    {:redirect, url.(row)}
  end

  defp do_execute_action(%{handle: handle}, row) when is_function(handle) do
    handle.(row)
  end

  defp load_selected_rows(table_module, "explicit", ids, _filters) do
    repo = table_module.repo()
    resource = table_module.resource()

    import Ecto.Query
    rows = repo.all(from(r in resource, where: r.id in ^ids))
    {:ok, rows}
  end

  defp load_selected_rows(table_module, "all", _ids, filters) do
    repo = table_module.repo()
    resource = table_module.resource()
    flop_filters = parse_filters(filters)

    case Flop.validate(%{filters: flop_filters}, for: resource) do
      {:ok, flop} ->
        query = Flop.query(resource, flop)
        {:ok, repo.all(query)}

      {:error, _} ->
        {:ok, repo.all(resource)}
    end
  end

  defp load_selected_rows(table_module, "all_except", excluded_ids, filters) do
    repo = table_module.repo()
    resource = table_module.resource()
    flop_filters = parse_filters(filters)

    import Ecto.Query

    query =
      case Flop.validate(%{filters: flop_filters}, for: resource) do
        {:ok, flop} -> Flop.query(resource, flop)
        {:error, _} -> resource
      end

    rows = repo.all(from(r in query, where: r.id not in ^excluded_ids))
    {:ok, rows}
  end

  defp load_selected_rows(_table_module, _mode, _ids, _filters) do
    {:error, :validation}
  end

  defp parse_filters(filters), do: NbFlop.Params.parse_filters(filters)

  defp run_callback(nil, _rows), do: :ok
  defp run_callback(callback, rows), do: callback.(rows)

  defp execute_in_chunks(handle, rows, chunk_size) do
    rows
    |> Stream.chunk_every(chunk_size)
    |> Enum.reduce_while(:ok, fn chunk, _acc ->
      case handle.(chunk) do
        :ok -> {:cont, :ok}
        {:ok, _} = result -> {:cont, result}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp raise_error(:not_found), do: raise_error(:not_found, "Not found")
  defp raise_error(:forbidden), do: raise_error(:forbidden, "Not authorized")
  defp raise_error(:validation), do: raise_error(:validation, "Invalid input")
  defp raise_error(reason) when is_binary(reason), do: raise_error(:internal, reason)
  defp raise_error(reason), do: raise_error(:internal, inspect(reason))

  defp raise_error(code, message) do
    error_mod = Module.concat([NbRpc, Error])

    if Code.ensure_loaded?(error_mod) do
      raise error_mod, code: code, message: message
    else
      raise RuntimeError, "#{code}: #{message}"
    end
  end
end
