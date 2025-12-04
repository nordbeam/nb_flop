defmodule NbFlop.Table.Compiler do
  @moduledoc """
  Compiles table definitions into behaviour implementations.
  """

  defmacro __before_compile__(env) do
    resource = Module.get_attribute(env.module, :nb_flop_resource)
    repo = Module.get_attribute(env.module, :nb_flop_repo)
    config = Module.get_attribute(env.module, :nb_flop_config)
    columns = Module.get_attribute(env.module, :nb_flop_columns) |> Enum.reverse()
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
        def selectable?(_row, _conn), do: true
      end

      unless Module.defines?(__MODULE__, {:transform_row, 3}) do
        @impl NbFlop.Table
        def transform_row(_row, data, _conn), do: data
      end

      @doc """
      Builds the table resource for rendering.

      Returns a map containing all data needed by the frontend Table component.
      """
      def make(conn, params, opts \\ []) do
        NbFlop.Table.Builder.build(__MODULE__, conn, params, opts)
      end
    end
  end
end
