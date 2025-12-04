if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.NbFlop.Install do
    @moduledoc """
    Installs nb_flop - Flop integration for the nb ecosystem.

    ## What it does
    - Adds the `:flop` dependency
    - Generates serializers to your `lib/your_app_web/serializers/` directory
    - Copies React components to `assets/js/components/flop/`
    - Installs required npm packages (@tanstack/react-table)

    ## Prerequisites
    Components use shadcn/ui. Install required components first:

        npx shadcn@latest add button badge popover dropdown-menu command input

    ## Usage

        mix nb_flop.install                  # Basic install
        mix nb_flop.install --table          # With Table DSL sample
        mix nb_flop.install --with-views     # With saved views support

    ## Options

    - `--table` - Generate sample Table DSL module and routes
    - `--with-views` - Include saved views support (requires migrations)
    - `--with-exports` - Include CSV export support

    ## Generated Files

    ### Serializers (Elixir)
    - `FlopFilterSerializer` - Serializes Flop.Filter structs
    - `FlopParamsSerializer` - Serializes Flop query params
    - `FlopMetaSerializer` - Serializes Flop.Meta with schema introspection
    - `FilterableFieldSerializer` - Serializes field metadata

    ### Components (React with shadcn/ui)
    - `types.ts`, `tableTypes.ts` - TypeScript type definitions
    - `useFlopParams.ts` - Hook for Flop state management
    - `filterOperators.ts`, `filterUtils.ts` - Filter utilities
    - `Pagination.tsx`, `CursorPagination.tsx` - Pagination components
    - `SortableHeader.tsx`, `SortableColumnHeader.tsx` - Sort headers
    - `DataTable.tsx` - TanStack Table wrapper
    - `FilterForm.tsx`, `FilterBar.tsx` - Filter components
    - `FilterChip.tsx`, `AddFilterButton.tsx` - Linear-style filters
    - `FilterValueInput.tsx`, `FilterValueSelect.tsx` - Filter inputs
    - `FilterModeToggle.tsx` - AND/OR filter mode toggle
    - `Table.tsx` - High-level Table DSL component
    - `index.ts` - Re-exports
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        group: :nb,
        schema: [
          table: :boolean,
          with_views: :boolean,
          with_exports: :boolean,
          yes: :boolean
        ],
        defaults: [
          table: false,
          with_views: false,
          with_exports: false,
          yes: false
        ],
        positional: [],
        composes: ["deps.get"],
        example: "mix nb_flop.install --table"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      with_table = igniter.args.options[:table]
      with_views = igniter.args.options[:with_views]
      with_exports = igniter.args.options[:with_exports]

      igniter
      |> print_welcome(with_table)
      |> add_dependencies(with_exports)
      |> generate_serializers()
      |> copy_components()
      |> maybe_add_routes(with_table)
      |> maybe_generate_sample_table(with_table)
      |> maybe_setup_views(with_views)
      |> install_npm_packages()
      |> print_success(with_table)
    end

    # Print welcome message
    defp print_welcome(igniter, with_table) do
      mode = if with_table, do: "With Table DSL sample", else: "Basic"

      message = """
      ╔═════════════════════════════════════════════════════════════════╗
      ║                    NbFlop Installer                              ║
      ║                                                                  ║
      ║  Installing Flop integration for pagination, sorting, and        ║
      ║  filtering with nb_serializer and React components.              ║
      ║                                                                  ║
      ║  Mode: #{String.pad_trailing(mode, 24)}                          ║
      ║  Components: shadcn/ui based                                     ║
      ╚═════════════════════════════════════════════════════════════════╝
      """

      Igniter.add_notice(igniter, message)
    end

    # Add flop dependency
    defp add_dependencies(igniter, with_exports) do
      igniter = Igniter.Project.Deps.add_dep(igniter, {:flop, "~> 0.26"})

      if with_exports do
        Igniter.Project.Deps.add_dep(igniter, {:csv, "~> 3.2"})
      else
        igniter
      end
    end

    # Generate serializers to user's codebase
    defp generate_serializers(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      serializers_module = Module.concat(web_module, "Serializers")

      igniter
      |> generate_flop_filter_serializer(serializers_module)
      |> generate_flop_params_serializer(serializers_module)
      |> generate_filterable_field_serializer(serializers_module)
      |> generate_flop_meta_serializer(serializers_module)
    end

    defp generate_flop_filter_serializer(igniter, base) do
      module = Module.concat(base, "FlopFilterSerializer")

      content = """
      defmodule #{inspect(module)} do
        @moduledoc \"\"\"
        Serializes Flop.Filter structs.

        Generated by nb_flop. Customize as needed.
        \"\"\"

        use NbSerializer.Serializer

        schema do
          field :field, :string
          field :op, :string, compute: :compute_op
          field :value, :any
        end

        def compute_op(filter, _opts) do
          case filter.op do
            op when is_atom(op) -> Atom.to_string(op)
            op -> op
          end
        end
      end
      """

      Igniter.create_new_file(igniter, module_to_path(module), content, on_exists: :skip)
    end

    defp generate_flop_params_serializer(igniter, base) do
      module = Module.concat(base, "FlopParamsSerializer")
      filter_module = Module.concat(base, "FlopFilterSerializer")

      content = """
      defmodule #{inspect(module)} do
        @moduledoc \"\"\"
        Serializes Flop query parameters.

        Generated by nb_flop. Customize as needed.
        \"\"\"

        use NbSerializer.Serializer

        alias #{inspect(filter_module)}

        schema do
          # Ordering
          field :order_by, list: :string, compute: :compute_order_by, optional: true
          field :order_directions, list: :string, compute: :compute_order_directions, optional: true

          # Page-based pagination
          field :page, :number, optional: true, nullable: true
          field :page_size, :number, optional: true, nullable: true

          # Offset-based pagination
          field :offset, :number, optional: true, nullable: true
          field :limit, :number, optional: true, nullable: true

          # Cursor-based pagination
          field :first, :number, optional: true, nullable: true
          field :last, :number, optional: true, nullable: true
          field :after, :string, optional: true, nullable: true
          field :before, :string, optional: true, nullable: true

          # Filters
          has_many :filters, FlopFilterSerializer
        end

        def compute_order_by(flop, _opts) do
          case flop.order_by do
            nil -> nil
            fields when is_list(fields) -> Enum.map(fields, &to_string/1)
          end
        end

        def compute_order_directions(flop, _opts) do
          case flop.order_directions do
            nil -> nil
            dirs when is_list(dirs) -> Enum.map(dirs, &Atom.to_string/1)
          end
        end
      end
      """

      Igniter.create_new_file(igniter, module_to_path(module), content, on_exists: :skip)
    end

    defp generate_filterable_field_serializer(igniter, base) do
      module = Module.concat(base, "FilterableFieldSerializer")

      content = """
      defmodule #{inspect(module)} do
        @moduledoc \"\"\"
        Serializes filterable field metadata.

        Generated by nb_flop. Customize as needed.
        \"\"\"

        use NbSerializer.Serializer

        schema do
          field :field, :string
          field :label, :string
          field :type, enum: ["string", "number", "boolean", "date", "datetime", "array", "enum"]
          field :operators, list: :string
        end
      end
      """

      Igniter.create_new_file(igniter, module_to_path(module), content, on_exists: :skip)
    end

    defp generate_flop_meta_serializer(igniter, base) do
      module = Module.concat(base, "FlopMetaSerializer")
      params_module = Module.concat(base, "FlopParamsSerializer")
      filterable_module = Module.concat(base, "FilterableFieldSerializer")

      content = """
      defmodule #{inspect(module)} do
        @moduledoc \"\"\"
        Serializes Flop.Meta with schema introspection.

        Generated by nb_flop. Customize as needed.

        ## Usage

            render_inertia(conn, :posts_index,
              posts: {PostSerializer, posts},
              meta: {FlopMetaSerializer, meta, schema: Post}
            )

        The `schema` option enables sortable/filterable field introspection.
        \"\"\"

        use NbSerializer.Serializer

        alias #{inspect(params_module)}
        alias #{inspect(filterable_module)}

        schema do
          # Page-based pagination
          field :current_page, :number, nullable: true
          field :total_pages, :number, nullable: true
          field :previous_page, :number, nullable: true
          field :next_page, :number, nullable: true

          # Offset-based pagination
          field :current_offset, :number, nullable: true
          field :previous_offset, :number, nullable: true
          field :next_offset, :number, nullable: true

          # Cursor-based pagination
          field :start_cursor, :string, nullable: true
          field :end_cursor, :string, nullable: true

          # Shared
          field :has_previous_page, :boolean, from: :has_previous_page?
          field :has_next_page, :boolean, from: :has_next_page?
          field :page_size, :number, nullable: true
          field :total_count, :number, nullable: true

          # Flop params
          has_one :flop, FlopParamsSerializer

          # Schema introspection
          field :filterable_fields, list: FilterableFieldSerializer,
            compute: :compute_filterable_fields,
            optional: true
          field :sortable_fields, list: :string,
            compute: :compute_sortable_fields,
            optional: true
        end

        def compute_filterable_fields(_meta, opts) do
          case Keyword.get(opts, :schema) do
            nil ->
              nil

            schema ->
              if Code.ensure_loaded?(Flop.Schema) and
                   function_exported?(Flop.Schema, :filterable, 1) do
                try do
                  schema
                  |> Flop.Schema.filterable()
                  |> build_filterable_fields(schema)
                rescue
                  _ -> nil
                end
              else
                nil
              end
          end
        end

        def compute_sortable_fields(_meta, opts) do
          case Keyword.get(opts, :schema) do
            nil ->
              nil

            schema ->
              if Code.ensure_loaded?(Flop.Schema) and
                   function_exported?(Flop.Schema, :sortable, 1) do
                try do
                  schema
                  |> Flop.Schema.sortable()
                  |> Enum.map(&to_string/1)
                rescue
                  _ -> nil
                end
              else
                nil
              end
          end
        end

        defp build_filterable_fields(fields, schema) do
          Enum.map(fields, fn field ->
            %{
              field: to_string(field),
              label: field |> to_string() |> String.replace("_", " ") |> String.capitalize(),
              type: infer_type(schema, field),
              operators: infer_operators(schema, field)
            }
          end)
        end

        defp infer_type(schema, field) do
          try do
            case schema.__schema__(:type, field) do
              :boolean -> "boolean"
              type when type in [:integer, :float, :decimal] -> "number"
              type when type in [:date, :naive_datetime, :utc_datetime] -> "datetime"
              {:array, _} -> "array"
              {:parameterized, Ecto.Enum, _} -> "enum"
              _ -> "string"
            end
          rescue
            _ -> "string"
          end
        end

        defp infer_operators(_schema, _field) do
          # Default operators - customize per field type if needed
          ["==", "!=", "=~", "ilike", "empty", "not_empty"]
        end
      end
      """

      Igniter.create_new_file(igniter, module_to_path(module), content, on_exists: :skip)
    end

    # Copy React components to user's assets
    defp copy_components(igniter) do
      priv_dir = :code.priv_dir(:nb_flop)
      source_path = Path.join([priv_dir, "components", "flop"])
      dest_path = "assets/js/components/flop"

      # All shadcn-based components from nb_pingcrm
      component_files = [
        "types.ts",
        "tableTypes.ts",
        "useFlopParams.ts",
        "filterOperators.ts",
        "filterUtils.ts",
        "Pagination.tsx",
        "CursorPagination.tsx",
        "SortableHeader.tsx",
        "SortableColumnHeader.tsx",
        "DataTable.tsx",
        "FilterForm.tsx",
        "FilterBar.tsx",
        "FilterChip.tsx",
        "AddFilterButton.tsx",
        "FilterValueInput.tsx",
        "FilterValueSelect.tsx",
        "FilterModeToggle.tsx",
        "Table.tsx",
        "index.ts"
      ]

      Enum.reduce(component_files, igniter, fn filename, acc ->
        source_file = Path.join(source_path, filename)
        dest_file = Path.join(dest_path, filename)

        if File.exists?(source_file) do
          content = File.read!(source_file)
          Igniter.create_new_file(acc, dest_file, content, on_exists: :skip)
        else
          acc
        end
      end)
    end

    # Install npm packages
    defp install_npm_packages(igniter) do
      pkg_manager = detect_package_manager()

      # TanStack Table is required for DataTable component
      # shadcn components (button, badge, popover, etc.) should already be installed by user
      packages = "@tanstack/react-table"

      install_cmd =
        case pkg_manager do
          "bun" -> "cd assets && bun add #{packages}"
          "pnpm" -> "cd assets && pnpm add #{packages}"
          "yarn" -> "cd assets && yarn add #{packages}"
          _ -> "cd assets && npm install #{packages}"
        end

      Igniter.add_task(igniter, "cmd", [install_cmd])
    end

    defp detect_package_manager do
      cond do
        File.exists?("assets/bun.lockb") -> "bun"
        File.exists?("assets/pnpm-lock.yaml") -> "pnpm"
        File.exists?("assets/yarn.lock") -> "yarn"
        File.exists?("assets/package-lock.json") -> "npm"
        System.find_executable("bun") -> "bun"
        System.find_executable("pnpm") -> "pnpm"
        System.find_executable("yarn") -> "yarn"
        true -> "npm"
      end
    end

    defp module_to_path(module) do
      path =
        module
        |> inspect()
        |> Macro.underscore()

      "lib/#{path}.ex"
    end

    # Add routes for Table DSL
    defp maybe_add_routes(igniter, false), do: igniter

    defp maybe_add_routes(igniter, true) do
      Igniter.add_notice(igniter, """

      Add NbFlop routes to your router:

          use NbFlop.Router

          scope "/" do
            pipe_through [:browser]

            # Add NbFlop action/export routes
            nb_flop_routes()
          end
      """)
    end

    # Generate sample table module
    defp maybe_generate_sample_table(igniter, false), do: igniter

    defp maybe_generate_sample_table(igniter, true) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      tables_module = Module.concat([web_module, "Tables", "ExampleTable"])

      content = """
      defmodule #{inspect(tables_module)} do
        @moduledoc \"\"\"
        Example table module demonstrating the NbFlop Table DSL.

        Use this as a template for your own tables.
        \"\"\"

        use NbFlop.Table

        # Point to your Ecto schema
        # resource MyApp.Accounts.User
        # repo MyApp.Repo

        config do
          name "example"
          default_sort {:inserted_at, :desc}
          default_per_page 25
          per_page_options [10, 25, 50, 100]
        end

        columns do
          text_column :name, sortable: true, searchable: true
          text_column :email, sortable: true
          badge_column :status, colors: %{"active" => :success, "inactive" => :danger}
          date_column :inserted_at, label: "Created", sortable: true
          action_column()
        end

        filters do
          text_filter :name, clauses: [:contains, :starts_with, :equals]
          set_filter :status, options: [{"active", "Active"}, {"inactive", "Inactive"}]
        end

        actions do
          action :edit,
            url: fn row -> "/example/\#{row.id}/edit" end,
            icon: "PencilIcon"

          action :delete,
            handle: fn _row -> :ok end,
            icon: "TrashIcon",
            variant: :danger,
            confirmation: %{
              title: "Delete Item",
              message: "Are you sure you want to delete this item?"
            }
        end

        bulk_actions do
          bulk_action :delete,
            handle: fn rows -> Enum.each(rows, fn _row -> :ok end) end,
            variant: :danger,
            confirmation: %{
              title: "Delete Items",
              message: "Are you sure you want to delete {count} items?"
            }
        end
      end
      """

      Igniter.create_new_file(igniter, module_to_path(tables_module), content, on_exists: :skip)
    end

    # Setup views (migrations and config)
    defp maybe_setup_views(igniter, false), do: igniter

    defp maybe_setup_views(igniter, true) do
      Igniter.add_notice(igniter, """

      To enable saved views, run the migration generator:

          mix ecto.gen.migration create_nb_flop_saved_views

      Then copy the migration content from nb_flop/priv/templates/migrations/

      Configure views in your config:

          config :nb_flop, :views,
            repo: MyApp.Repo,
            schema: NbFlop.Views.SavedView
      """)
    end

    # Print success message
    defp print_success(igniter, with_table) do
      table_sample =
        if with_table do
          """

          Example Table Module:
            • lib/your_app_web/tables/example_table.ex
          """
        else
          ""
        end

      table_usage =
        if with_table do
          """

          ## Table DSL Usage

          The Table DSL provides a declarative way to build data tables:

          1. Create a table module:

          defmodule MyAppWeb.Tables.UsersTable do
            use NbFlop.Table

            resource MyApp.Accounts.User
            repo MyApp.Repo

            config do
              name "users"
              default_sort {:name, :asc}
            end

            columns do
              text_column :name, sortable: true
              text_column :email
              badge_column :status, colors: %{"active" => :success}
              action_column()
            end

            actions do
              action :edit, url: fn user -> "/users/\#{user.id}/edit" end
            end
          end

          2. Use in your controller:

          def index(conn, params) do
            render_inertia(conn, :users_index,
              users: MyAppWeb.Tables.UsersTable.make(conn, params)
            )
          end

          3. Use in your frontend:

          import { Table } from '@/components/flop';

          function UsersIndex({ users }) {
            return <Table resource={users} baseUrl="/users" />;
          }

          The Table component handles sorting, pagination, filtering, and actions automatically!
          """
        else
          ""
        end

      success_message = """

      ╔═══════════════════════════════════════════════════════════════╗
      ║                  NbFlop Installed!                             ║
      ╚═══════════════════════════════════════════════════════════════╝

      Files Created:

      Serializers:
        • lib/your_app_web/serializers/flop_filter_serializer.ex
        • lib/your_app_web/serializers/flop_params_serializer.ex
        • lib/your_app_web/serializers/flop_meta_serializer.ex
        • lib/your_app_web/serializers/filterable_field_serializer.ex

      React Components (shadcn/ui based):
        • assets/js/components/flop/types.ts
        • assets/js/components/flop/tableTypes.ts
        • assets/js/components/flop/useFlopParams.ts
        • assets/js/components/flop/filterOperators.ts
        • assets/js/components/flop/filterUtils.ts
        • assets/js/components/flop/Pagination.tsx
        • assets/js/components/flop/CursorPagination.tsx
        • assets/js/components/flop/SortableHeader.tsx
        • assets/js/components/flop/SortableColumnHeader.tsx
        • assets/js/components/flop/DataTable.tsx
        • assets/js/components/flop/FilterForm.tsx
        • assets/js/components/flop/FilterBar.tsx
        • assets/js/components/flop/FilterChip.tsx
        • assets/js/components/flop/AddFilterButton.tsx
        • assets/js/components/flop/FilterValueInput.tsx
        • assets/js/components/flop/FilterValueSelect.tsx
        • assets/js/components/flop/FilterModeToggle.tsx
        • assets/js/components/flop/Table.tsx
        • assets/js/components/flop/index.ts
      #{table_sample}
      #{table_usage}
      ## Prerequisites

      These components use shadcn/ui. Ensure you have installed:

          npx shadcn@latest add button badge popover dropdown-menu command input

      ## Basic Usage

      1. Add @derive Flop.Schema to your Ecto schemas:

          @derive {
            Flop.Schema,
            filterable: [:title, :status],
            sortable: [:title, :inserted_at]
          }
          schema "posts" do
            ...
          end

      2. Use in your controller with FlopMetaSerializer

      3. Use Pagination, FilterBar, DataTable, etc. in frontend

      Style the components as needed - they're in your codebase!
      """

      Igniter.add_notice(igniter, success_message)
    end
  end
end
