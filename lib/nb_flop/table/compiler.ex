defmodule NbFlop.Table.Compiler do
  @moduledoc """
  Compiles table definitions into behaviour implementations.
  """

  defmacro __before_compile__(env) do
    resource = Module.get_attribute(env.module, :nb_flop_resource)
    repo = Module.get_attribute(env.module, :nb_flop_repo)
    config = Module.get_attribute(env.module, :nb_flop_config)
    columns = Module.get_attribute(env.module, :nb_flop_columns) |> Enum.reverse()
    ts_extra_fields = Module.get_attribute(env.module, :nb_flop_ts_extra_fields) |> Enum.reverse()
    filters = Module.get_attribute(env.module, :nb_flop_filters) |> Enum.reverse()
    actions = Module.get_attribute(env.module, :nb_flop_actions) |> Enum.reverse()
    bulk_actions = Module.get_attribute(env.module, :nb_flop_bulk_actions) |> Enum.reverse()
    empty_state = Module.get_attribute(env.module, :nb_flop_empty_state)
    exports = Module.get_attribute(env.module, :nb_flop_exports) |> Enum.reverse()
    views_config = Module.get_attribute(env.module, :nb_flop_views_config)

    # Validate required fields
    unless resource do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "NbFlop.Table requires a `resource` to be defined"
    end

    unless repo do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "NbFlop.Table requires a `repo` to be defined"
    end

    # Generate default config if not provided
    config =
      config ||
        quote do
          NbFlop.Table.Config.default(unquote(Macro.to_string(env.module)))
        end

    # Validate searchable fields match Flop compound fields (if Flop.Schema is derived)
    searchable =
      case config do
        %NbFlop.Table.Config{searchable: fields} when is_list(fields) and fields != [] ->
          fields

        _ ->
          []
      end

    if searchable != [] do
      # Check if resource has Flop.Schema derived with a :search compound field
      if Code.ensure_loaded?(resource) do
        search_info =
          try do
            Flop.Schema.field_info(struct(resource), :search)
          rescue
            _ -> nil
          end

        case search_info do
          %{extra: %{type: :compound, fields: compound_fields}} ->
            missing = searchable -- compound_fields

            if missing != [] do
              IO.warn(
                "NbFlop table #{inspect(env.module)}: searchable fields #{inspect(missing)} " <>
                  "are not in the Flop.Schema compound_fields :search definition on #{inspect(resource)}. " <>
                  "Search will not query these fields. Either add them to @derive {Flop.Schema, " <>
                  "compound_fields: [search: #{inspect(compound_fields ++ missing)}]} " <>
                  "or remove them from the searchable config.",
                Macro.Env.stacktrace(env)
              )
            end

          _ ->
            IO.warn(
              "NbFlop table #{inspect(env.module)}: searchable is configured but #{inspect(resource)} " <>
                "does not define a :search compound field in its Flop.Schema derivation. " <>
                "Add `compound_fields: [search: #{inspect(searchable)}]` to the @derive.",
              Macro.Env.stacktrace(env)
            )
        end
      end
    end

    quote do
      @impl NbFlop.Table
      def resource, do: unquote(resource)

      @impl NbFlop.Table
      def repo, do: unquote(repo)

      @impl NbFlop.Table
      def config, do: unquote(Macro.escape(config))

      @impl NbFlop.Table
      def columns do
        unquote(
          Enum.map(columns, fn
            # Action column doesn't take a key argument
            {:action, _key, opts} ->
              quote do
                NbFlop.Column.action(unquote(opts))
              end

            {type, key, opts} ->
              quote do
                apply(NbFlop.Column, unquote(type), [unquote(key), unquote(opts)])
              end
          end)
        )
      end

      @impl NbFlop.Table
      def filters, do: unquote(Macro.escape(filters))

      @impl NbFlop.Table
      def actions do
        unquote(
          Enum.map(actions, fn {name, opts} ->
            quote do
              NbFlop.Action.new(unquote(name), unquote(opts))
            end
          end)
        )
      end

      @impl NbFlop.Table
      def bulk_actions do
        unquote(
          Enum.map(bulk_actions, fn {name, opts} ->
            quote do
              NbFlop.BulkAction.new(unquote(name), unquote(opts))
            end
          end)
        )
      end

      unless Module.defines?(__MODULE__, {:empty_state, 0}) do
        @impl NbFlop.Table
        def empty_state, do: unquote(Macro.escape(empty_state))
      end

      unless Module.defines?(__MODULE__, {:exports, 0}) do
        @impl NbFlop.Table
        def exports, do: unquote(Macro.escape(exports))
      end

      unless Module.defines?(__MODULE__, {:views_config, 0}) do
        @impl NbFlop.Table
        def views_config, do: unquote(Macro.escape(views_config))
      end

      unless Module.defines?(__MODULE__, {:selectable?, 2}) do
        @impl NbFlop.Table
        def selectable?(_row, _context), do: true
      end

      unless Module.defines?(__MODULE__, {:transform_row, 3}) do
        @impl NbFlop.Table
        def transform_row(_row, data, _context), do: data
      end

      @doc """
      Returns type metadata for TypeScript type generation via nb_ts.

      The returned map contains column types and any extra fields declared
      via `ts_field` for `transform_row` additions.
      """
      def __nb_flop_type_metadata__ do
        %{
          columns:
            unquote(
              columns
              |> Enum.reject(fn {type, _key, _opts} -> type == :action end)
              |> Enum.map(fn {type, key, opts} ->
                nullable = Keyword.get(opts, :nullable, false)
                ts_type = Keyword.get(opts, :ts_type, nil)

                Macro.escape(%{
                  key: key,
                  type: type,
                  nullable: nullable,
                  ts_type: ts_type
                })
              end)
            ),
          extra_fields:
            unquote(
              Enum.map(ts_extra_fields, fn {key, type, opts} ->
                nullable = Keyword.get(opts, :nullable, false)
                fields = Keyword.get(opts, :fields, nil)

                Macro.escape(%{
                  key: key,
                  type: type,
                  nullable: nullable,
                  fields: fields
                })
              end)
            )
        }
      end

      @doc """
      Builds the table resource for rendering.

      Returns a map containing all data needed by the frontend Table component.
      """
      def make(context, params, opts \\ []) do
        NbFlop.Table.Builder.build(__MODULE__, context, params, opts)
      end
    end
  end
end
