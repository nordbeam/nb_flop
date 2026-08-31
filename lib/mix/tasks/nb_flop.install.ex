if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.NbFlop.Install do
    @moduledoc """
    Installs nb_flop - Flop integration for the nb ecosystem.

    ## What it does
    - Adds the `:flop` dependency
    - Generates serializers to your `lib/your_app_web/serializers/` directory
    - Copies React components to `assets/js/components/flop/`
    - Installs required frontend packages (@tanstack/react-table, Lucide, shadcn)

    ## Prerequisites
    A Phoenix application with frontend assets is required. The installer
    initializes shadcn/ui when needed and adds every required component.
    For Vite+ projects, a globally installed `vp` is preferred. When it is
    unavailable, the installer runs the pinned Vite+ CLI through npm with
    `npm exec --yes --package=vite-plus@0.3.0 -- vp ...`.

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

    @task_group :nb
    @schema [
      table: :boolean,
      with_views: :boolean,
      with_exports: :boolean,
      yes: :boolean
    ]
    @defaults [
      table: false,
      with_views: false,
      with_exports: false,
      yes: false
    ]

    @impl Igniter.Mix.Task
    def info(argv, _parent) do
      options = installer_options(argv)

      %Igniter.Mix.Task.Info{
        group: @task_group,
        schema: @schema,
        defaults: @defaults,
        positional: [],
        adds_deps: optional_dependency_specs(options),
        example: "mix nb_flop.install --table"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      with_table = igniter.args.options[:table]
      with_views = igniter.args.options[:with_views]

      igniter
      |> ensure_optional_dependencies_added()
      |> print_welcome(with_table)
      |> generate_serializers()
      |> copy_components()
      |> maybe_add_routes(with_table)
      |> maybe_generate_sample_table(with_table)
      |> maybe_setup_views(with_views)
      |> install_frontend_packages()
      |> print_success(with_table)
    end

    @doc false
    def installer_options(argv) do
      group = Igniter.Util.Info.group(%Igniter.Mix.Task.Info{group: @task_group}, task_name())

      {options, _argv, _invalid} =
        argv
        |> Igniter.Util.Info.args_for_group(group)
        |> OptionParser.parse(switches: @schema)

      Keyword.merge(@defaults, options)
    end

    @doc false
    def optional_dependency_specs(options, installed_deps \\ installed_project_deps()) do
      []
      |> maybe_add_optional_dep(true, installed_deps, {:flop, "~> 0.28"})
      |> maybe_add_optional_dep(options[:with_exports], installed_deps, {:csv, "~> 3.2"})
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

    defp ensure_optional_dependencies_added(igniter) do
      missing_specs =
        igniter.args.options
        |> optional_dependency_specs()
        |> Enum.reject(fn spec -> dep_present?(igniter, dep_name(spec)) end)

      Enum.reduce(missing_specs, igniter, fn spec, igniter ->
        Igniter.Project.Deps.add_dep(igniter, spec)
      end)
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
        "ConfirmDialog.tsx",
        "SearchInput.tsx",
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

    # Install third-party frontend packages with the app's package manager.
    defp install_frontend_packages(igniter) do
      pkg_manager = detect_package_manager(igniter)
      components_exist? = Igniter.exists?(igniter, "assets/components.json")
      shadcn_components_exist? = shadcn_components_exist?(igniter)

      {runtime_cmd, cli_cmd, exec_prefix} =
        case pkg_manager do
          "vp" ->
            vp = vite_plus_prefix()

            {
              "#{vp} -C assets add @tanstack/react-table@^8.21.3 lucide-react",
              "#{vp} -C assets add -D shadcn@latest",
              "#{vp} -C assets exec shadcn"
            }

          "bun" ->
            {
              "cd assets && bun add @tanstack/react-table@^8.21.3 lucide-react",
              "cd assets && bun add -D shadcn@latest",
              "cd assets && bunx shadcn"
            }

          "pnpm" ->
            {
              "cd assets && pnpm add @tanstack/react-table@^8.21.3 lucide-react",
              "cd assets && pnpm add -D shadcn@latest",
              "cd assets && pnpm exec shadcn"
            }

          "yarn" ->
            {
              "cd assets && yarn add @tanstack/react-table@^8.21.3 lucide-react",
              "cd assets && yarn add -D shadcn@latest",
              "cd assets && yarn shadcn"
            }

          _ ->
            {
              "cd assets && npm install @tanstack/react-table@^8.21.3 lucide-react",
              "cd assets && npm install --save-dev shadcn@latest",
              "cd assets && npx shadcn"
            }
        end

      igniter
      |> Igniter.add_task("cmd", [runtime_cmd])
      |> Igniter.add_task("cmd", [cli_cmd])
      |> maybe_initialize_shadcn(exec_prefix, components_exist?)
      |> maybe_add_shadcn_components(exec_prefix, shadcn_components_exist?)
    end

    # Prefer a globally installed Vite+ executable, but keep Vite+ projects
    # installable on machines that only have npm available. The explicit
    # version makes the generated installer deterministic and avoids relying
    # on whichever Vite+ version happens to be resolved by npm at install time.
    @doc false
    def vite_plus_prefix(vp_path \\ System.find_executable("vp"))

    def vite_plus_prefix(nil),
      do: "npm exec --yes --package=vite-plus@0.3.0 -- vp"

    def vite_plus_prefix(_vp_path), do: "vp"

    defp maybe_initialize_shadcn(igniter, _exec_prefix, true), do: igniter

    defp maybe_initialize_shadcn(igniter, exec_prefix, false) do
      Igniter.add_task(igniter, "cmd", [
        "#{exec_prefix} init --template vite --base radix --preset nova --yes"
      ])
    end

    defp maybe_add_shadcn_components(igniter, _exec_prefix, true), do: igniter

    defp maybe_add_shadcn_components(igniter, exec_prefix, false) do
      Igniter.add_task(igniter, "cmd", [
        "#{exec_prefix} add button badge popover dropdown-menu command input dialog sheet --yes"
      ])
    end

    @doc false
    def shadcn_components_exist?(igniter, exists? \\ nil) do
      exists? = exists? || fn path -> Igniter.exists?(igniter, path) end

      ~w(button badge popover dropdown-menu command input dialog sheet)
      |> Enum.all?(&exists?.("assets/js/components/ui/#{&1}.tsx"))
    end

    defp detect_package_manager(igniter) do
      cond do
        vite_plus_project?(igniter) -> "vp"
        File.exists?("assets/bun.lockb") or File.exists?("assets/bun.lock") -> "bun"
        File.exists?("assets/pnpm-lock.yaml") -> "pnpm"
        File.exists?("assets/yarn.lock") -> "yarn"
        File.exists?("assets/package-lock.json") -> "npm"
        System.find_executable("bun") -> "bun"
        System.find_executable("pnpm") -> "pnpm"
        System.find_executable("yarn") -> "yarn"
        true -> "npm"
      end
    end

    defp vite_plus_project?(igniter) do
      case package_json_content(igniter) do
        {:ok, content} -> String.contains?(content, "vite-plus")
        _ -> false
      end
    end

    defp package_json_content(igniter) do
      path = "assets/package.json"

      if Rewrite.has_source?(igniter.rewrite, path) do
        {:ok, igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)}
      else
        File.read(path)
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

    # Generate sample table module with example schema
    defp maybe_generate_sample_table(igniter, false), do: igniter

    defp maybe_generate_sample_table(igniter, true) do
      app_name = Igniter.Project.Application.app_name(igniter)
      app_module = String.to_atom(Macro.camelize(to_string(app_name)))
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      schema_module = Module.concat([app_module, Examples, Item])
      tables_module = Module.concat([web_module, Tables, ExampleTable])
      repo_module = Module.concat([app_module, Repo])

      # Create the example schema first
      schema_content = """
      defmodule #{inspect(schema_module)} do
        @moduledoc \"\"\"
        Example schema for demonstrating the NbFlop Table DSL.

        Generated by nb_flop. This is a sample - create your own schemas
        and run migrations to use real data.
        \"\"\"

        use Ecto.Schema
        import Ecto.Changeset

        @derive {
          Flop.Schema,
          filterable: [:name, :email, :status],
          sortable: [:name, :email, :status, :inserted_at]
        }

        schema "example_items" do
          field :name, :string
          field :email, :string
          field :status, :string, default: "active"

          timestamps()
        end

        @doc false
        def changeset(item, attrs) do
          item
          |> cast(attrs, [:name, :email, :status])
          |> validate_required([:name, :email])
          |> validate_inclusion(:status, ["active", "inactive"])
        end
      end
      """

      # Create the table that references the schema
      table_content = """
      defmodule #{inspect(tables_module)} do
        @moduledoc \"\"\"
        Example table module demonstrating the NbFlop Table DSL.

        Use this as a template for your own tables.
        \"\"\"

        use NbFlop.Table

        resource #{inspect(schema_module)}
        repo #{inspect(repo_module)}

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

      igniter
      |> Igniter.create_new_file(module_to_path(schema_module), schema_content, on_exists: :skip)
      |> Igniter.create_new_file(module_to_path(tables_module), table_content, on_exists: :skip)
      |> Igniter.add_notice("""

      Example Table Created!

      To use the example table, create the migration:

          mix ecto.gen.migration create_example_items

      Add this to the migration:

          def change do
            create table(:example_items) do
              add :name, :string, null: false
              add :email, :string, null: false
              add :status, :string, default: "active"

              timestamps()
            end
          end

      Then run: mix ecto.migrate
      """)
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
        • assets/js/components/flop/SearchInput.tsx
        • assets/js/components/flop/ConfirmDialog.tsx
        • assets/js/components/flop/Table.tsx
        • assets/js/components/flop/index.ts
      #{table_sample}
      #{table_usage}
      The installer initialized shadcn/ui when needed and added button, badge,
      popover, dropdown-menu, command, input, dialog, and sheet components.

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

    defp maybe_add_optional_dep(specs, true, installed_deps, spec) do
      if dep_installed?(installed_deps, dep_name(spec)) do
        specs
      else
        specs ++ [spec]
      end
    end

    defp maybe_add_optional_dep(specs, _, _installed_deps, _spec), do: specs

    defp installed_project_deps do
      Mix.Project.config()
      |> Keyword.get(:deps, [])
      |> Enum.map(&dep_name/1)
    end

    defp dep_present?(igniter, dep) do
      case Igniter.Project.Deps.get_dep(igniter, dep) do
        {:ok, _} -> true
        _ -> false
      end
    end

    defp dep_installed?(installed_deps, dep), do: dep in installed_deps

    defp dep_name({dep, _, _}) when is_atom(dep), do: dep
    defp dep_name({dep, _}) when is_atom(dep), do: dep

    defp task_name do
      Mix.Task.task_name(__MODULE__)
    end
  end
else
  defmodule Mix.Tasks.NbFlop.Install do
    @shortdoc "Install `igniter` in order to install NbFlop."

    @moduledoc """
    The task 'nb_flop.install' requires igniter. Please install igniter and try again.

    Add to your mix.exs for direct task usage:

        {:igniter, "~> 0.7", only: [:dev, :test]}

    Or install Igniter first and use the preferred installer flow:

        mix igniter.install nb_flop
    """

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'nb_flop.install' requires igniter. Please install igniter and try again.

      Add to your mix.exs for direct task usage:

          {:igniter, "~> 0.7", only: [:dev, :test]}

      Or install Igniter first and use the preferred installer flow:

          mix igniter.install nb_flop

      Then run:

          mix deps.get
          mix nb_flop.install
      """)

      exit({:shutdown, 1})
    end
  end
end
