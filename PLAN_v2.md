# nb_flop Feature Expansion Plan v2 (Deep Analysis)

## Critical Architectural Insight: "Table as Resource" Pattern

The fundamental insight from Inertia Table is that **the Table class serializes itself as a complete resource**:

```php
// Laravel - Single call returns everything
return inertia('Users/Index', [
    'users' => Users::make(),  // Returns complete resource
]);
```

The frontend `<Table resource={users}>` is purely presentational - it renders what backend tells it.

**This is fundamentally different from current nb_flop** where:
- Backend sends: `data + FlopMeta`
- Frontend defines: columns (TanStack columnDefs), handles actions

**Decision**: Adopt the "Table as Resource" pattern where backend is single source of truth.

---

## What Actually Gets Serialized

When `UsersTable.make(conn, params)` is called, it returns:

```elixir
%{
  # Actual row data (transformed, with per-row action states)
  data: [
    %{
      id: 1,
      name: "John Doe",
      status: "active",
      _actions: %{
        "edit" => %{url: "/users/1/edit", disabled: false, hidden: false},
        "delete" => %{url: nil, disabled: true, hidden: false}  # Disabled for this row!
      },
      _selectable: true
    },
    # ...
  ],

  # Pagination meta (from Flop)
  meta: %{
    current_page: 1,
    total_pages: 10,
    total_count: 250,
    has_next_page: true,
    has_previous_page: false,
    page_size: 25,
    # ... flop fields
  },

  # Current table state (for URL sync)
  state: %{
    sort: %{field: "name", direction: "asc"},
    filters: [%{field: "status", op: "==", value: "active"}],
    page: 1,
    per_page: 25,
    search: "",
    columns: ["name", "email", "status", "created_at"],  # Visible columns
  },

  # Column definitions (static metadata for frontend rendering)
  columns: [
    %{key: "name", type: "text", label: "Name", sortable: true, searchable: true,
      toggleable: true, visible: true, alignment: "left"},
    %{key: "status", type: "badge", label: "Status", sortable: true,
      colors: %{"active" => "success", "inactive" => "danger"}},
    %{key: "created_at", type: "date", label: "Created", format: "MMM d, yyyy"},
    %{key: "_actions", type: "action"}
  ],

  # Filter definitions
  filters: [
    %{field: "name", type: "text", label: "Name",
      clauses: ["contains", "starts_with", "equals"]},
    %{field: "status", type: "set", label: "Status",
      options: [%{value: "active", label: "Active"}, %{value: "inactive", label: "Inactive"}]},
    %{field: "created_at", type: "date", label: "Created"}
  ],

  # Action definitions (static - per-row state is in data._actions)
  actions: [
    %{name: "edit", label: "Edit", icon: "PencilIcon", variant: "default"},
    %{name: "delete", label: "Delete", icon: "TrashIcon", variant: "danger",
      confirmation: %{
        title: "Delete User",
        message: "Are you sure you want to delete this user?",
        confirm_button: "Delete",
        cancel_button: "Cancel"
      }}
  ],

  # Bulk actions
  bulk_actions: [
    %{name: "delete_selected", label: "Delete Selected",
      confirmation: %{title: "Delete Users", message: "Delete {count} users?"}}
  ],

  # Exports
  exports: [
    %{name: "csv", label: "Export CSV"},
    %{name: "excel", label: "Export Excel"}
  ],

  # Empty state
  empty_state: %{
    title: "No users found",
    message: "Get started by creating your first user.",
    icon: "UsersIcon",
    action: %{label: "Create User", url: "/users/new", variant: "primary"}
  },

  # Saved views
  views: %{
    enabled: true,
    list: [
      %{id: "1", name: "Active Users", is_default: false},
      %{id: "2", name: "Recent Signups", is_default: true}
    ],
    current: "2"
  },

  # Table config
  name: "users",  # For URL namespacing
  token: "eyJhbGc...",  # Signed token for action authentication
  per_page_options: [10, 25, 50, 100],
  sticky_header: true,
  searchable: true,
  search_placeholder: "Search users..."
}
```

---

## Critical Detail: Per-Row Action Evaluation

**This is the most important insight I missed initially.**

Actions have callbacks that are **evaluated per-row**:

```php
Action::make('Delete')
    ->disabled(fn(User $user) => $user->is_admin)  // Different result per row!
    ->hidden(fn(User $user) => !auth()->user()->can('delete', $user));
```

This means during serialization, for EACH row, we must:
1. Call `disabled.(row)` → get boolean
2. Call `hidden.(row)` → get boolean
3. Call `url.(row)` → get URL string (if it's a link action)

The results go into `row._actions`:

```elixir
%{
  id: 1,
  name: "Regular User",
  _actions: %{
    "delete" => %{disabled: false, hidden: false, url: nil}
  }
}

%{
  id: 2,
  name: "Admin User",
  _actions: %{
    "delete" => %{disabled: true, hidden: false, url: nil}  # DIFFERENT!
  }
}
```

The frontend reads `row._actions[actionName].disabled` to render the button state.

---

## Integration with Flop

**Decision: Wrap Flop, don't replace it.**

Flop already handles:
- Sorting (including relationships via power-joins)
- Filtering (with operators: ==, !=, ilike, >, <, etc.)
- Pagination (page, offset, cursor)
- Validation
- Meta struct generation

We add ON TOP of Flop:
- Column definitions (frontend rendering hints)
- Value transformations (mapAs)
- Actions with handlers
- Bulk actions
- Exports
- Views persistence
- Empty state

Architecture:
```
Table.make(conn, params)
  │
  ├─→ 1. Parse params (respect table name prefix for multiple tables)
  │
  ├─→ 2. Flop.validate_and_run(resource, flop_params, for: schema)
  │      Returns: {rows, %Flop.Meta{}}
  │
  ├─→ 3. Transform each row:
  │      - Apply column.map_as transformations
  │      - Evaluate action states (disabled/hidden/url per row)
  │      - Add _actions map to row
  │      - Evaluate isSelectable for bulk actions
  │
  ├─→ 4. Load saved views for current user
  │
  ├─→ 5. Generate signed token (encodes table module + context)
  │
  └─→ 6. Serialize everything via TableSerializer
```

---

## Action Execution Flow

When user clicks "Delete" on a row:

### Step 1: Frontend shows confirmation dialog (if configured)
```tsx
// User clicks action button
const action = actions.find(a => a.name === 'delete');
if (action.confirmation) {
  setConfirmDialog({ action, item: row });
  return;
}
executeAction(action, row);
```

### Step 2: Frontend POSTs to action endpoint
```tsx
async function executeAction(action: Action, row: Row) {
  const response = await fetch('/nb-flop/action', {
    method: 'POST',
    body: JSON.stringify({
      token: resource.token,
      action: action.name,
      id: row.id
    })
  });

  const result = await response.json();
  if (result.success) {
    // Refresh table via Inertia
    router.reload({ only: ['users'] });
  } else {
    showError(result.message);
  }
}
```

### Step 3: Backend handles action
```elixir
defmodule NbFlop.ActionController do
  def execute(conn, %{"token" => token, "action" => action_name, "id" => id}) do
    with {:ok, %{table: table_module}} <- NbFlop.Token.verify(token),
         action <- find_action(table_module, action_name),
         :ok <- authorize(action, conn),
         row <- load_row(table_module, id),
         :ok <- check_not_disabled(action, row),
         result <- action.handle.(row) do
      case result do
        :ok -> json(conn, %{success: true, message: action.success_message})
        {:ok, message} -> json(conn, %{success: true, message: message})
        {:error, reason} -> json(conn, %{success: false, message: reason})
      end
    else
      {:error, reason} -> json(conn, %{success: false, message: to_string(reason)})
    end
  end
end
```

### Step 4: Frontend refreshes
```tsx
// After successful action, Inertia reloads the table data
router.reload({ only: ['users'], preserveScroll: true });
```

---

## Security: Signed Tokens

The action endpoint needs to know which Table module handles the request.

**Problem**: Can't just pass module name - attacker could invoke any module.

**Solution**: Sign the table reference in a token.

```elixir
defmodule NbFlop.Token do
  @salt "nb_flop_action_v1"

  def sign(table_module, context \\ %{}) do
    Phoenix.Token.sign(
      endpoint(),
      @salt,
      %{
        table: Module.split(table_module) |> Enum.join("."),
        context: context,
        issued_at: System.system_time(:second)
      }
    )
  end

  def verify(token, max_age \\ 86400) do
    case Phoenix.Token.verify(endpoint(), @salt, token, max_age: max_age) do
      {:ok, %{table: table_string} = data} ->
        table_module = Module.concat([table_string])
        # Verify the module exists and is a valid table
        if Code.ensure_loaded?(table_module) and function_exported?(table_module, :__nb_flop_table__, 0) do
          {:ok, %{data | table: table_module}}
        else
          {:error, :invalid_table}
        end
      error -> error
    end
  end
end
```

The token is generated during `Table.make()` and included in the serialized resource. Frontend passes it back with every action request.

---

## Column Types and Transformations

### Column Definition Structure

```elixir
defmodule NbFlop.Column do
  @type t :: %__MODULE__{
    key: atom(),
    type: :text | :badge | :numeric | :date | :datetime | :boolean | :image | :action,
    label: String.t(),
    sortable: boolean(),
    searchable: boolean(),
    toggleable: boolean(),
    visible: boolean(),
    stickable: boolean(),
    alignment: :left | :center | :right,
    wrap: boolean(),
    truncate: boolean(),
    header_class: String.t() | nil,
    cell_class: String.t() | nil,
    clickable: (map() -> String.t() | nil) | nil,
    map_as: (any() -> any()) | nil,
    meta: map(),
    # Type-specific options
    opts: map()
  }
end
```

### Type-Specific Options

```elixir
# Badge column
%{colors: %{"active" => "success", "inactive" => "danger"}}

# Numeric column
%{prefix: "$", suffix: nil, decimals: 2, thousands_separator: ","}

# Date/DateTime column
%{format: "MMM d, yyyy"}

# Image column
%{width: 40, height: 40, rounded: true, fallback: "/images/default.png"}
```

### Transformation Flow

```elixir
def transform_row(row, columns) do
  row
  |> Enum.reduce(%{}, fn {key, value}, acc ->
    column = Enum.find(columns, &(&1.key == key))
    transformed = if column && column.map_as do
      column.map_as.(value)
    else
      value
    end
    Map.put(acc, key, transformed)
  end)
end
```

---

## Views (Saved Table States)

### Database Schema

```elixir
defmodule NbFlop.TableView do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "nb_flop_table_views" do
    field :name, :string
    field :table_name, :string  # "MyApp.Tables.UsersTable" or custom name
    field :user_id, :string     # nil for shared views
    field :state, :map          # {sort, filters, columns, per_page, search}
    field :is_default, :boolean, default: false
    field :shared, :boolean, default: false
    field :attributes, :map     # Custom attributes like tenant_id

    timestamps()
  end
end
```

### Migration

```elixir
defmodule NbFlop.Migrations.CreateTableViews do
  use Ecto.Migration

  def change do
    create table(:nb_flop_table_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :table_name, :string, null: false
      add :user_id, :string
      add :state, :map, null: false
      add :is_default, :boolean, default: false
      add :shared, :boolean, default: false
      add :attributes, :map, default: %{}

      timestamps()
    end

    create index(:nb_flop_table_views, [:table_name])
    create index(:nb_flop_table_views, [:user_id])
    create index(:nb_flop_table_views, [:table_name, :user_id])
  end
end
```

### Views Configuration in Table

```elixir
defmodule MyApp.Tables.UsersTable do
  use NbFlop.Table

  views do
    enabled true
    scope_user true  # Each user sees their own views
    user_resolver fn conn -> conn.assigns.current_user.id end
    attributes fn conn -> %{tenant_id: conn.assigns.tenant_id} end
  end
end
```

### Views API Endpoints

```elixir
scope "/nb-flop/views", NbFlop.ViewsController do
  get "/", :index        # List views for table
  post "/", :create      # Create new view
  put "/:id", :update    # Update view
  delete "/:id", :delete # Delete view
  post "/:id/default", :set_default  # Set as default
end
```

---

## Bulk Actions and Selection

### Selection State Management

Selection is frontend state, but "select all" is tricky because data is paginated.

**Approach 1: Track IDs** (for small datasets)
```tsx
const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
```

**Approach 2: Track "all selected" flag** (for large datasets)
```tsx
const [selection, setSelection] = useState<{
  mode: 'explicit' | 'all' | 'all_except';
  ids: Set<string>;
}>({ mode: 'explicit', ids: new Set() });
```

When executing bulk action:
- If `mode === 'explicit'`: Send IDs array
- If `mode === 'all'`: Send flag + current filters (backend queries all matching)
- If `mode === 'all_except'`: Send flag + excluded IDs + filters

### Bulk Action Execution

```elixir
def execute_bulk(conn, %{
  "token" => token,
  "action" => action_name,
  "selection" => %{"mode" => mode} = selection
}) do
  with {:ok, %{table: table_module}} <- NbFlop.Token.verify(token),
       action <- find_bulk_action(table_module, action_name),
       :ok <- authorize_bulk(action, conn),
       rows <- load_selected_rows(table_module, selection, conn.params),
       :ok <- execute_in_chunks(action, rows) do
    json(conn, %{success: true, count: length(rows)})
  end
end

defp load_selected_rows(table, %{"mode" => "explicit", "ids" => ids}, _params) do
  table.__resource__()
  |> where([r], r.id in ^ids)
  |> table.__repo__().all()
end

defp load_selected_rows(table, %{"mode" => "all"}, params) do
  # Apply same filters as table view, but get ALL rows (no pagination)
  flop_params = extract_flop_params(params)
  table.__resource__()
  |> Flop.query(flop_params, for: table.__flop_schema__())
  |> table.__repo__().all()
end

defp execute_in_chunks(action, rows) do
  chunk_size = action.chunk_size || 100

  rows
  |> Stream.chunk_every(chunk_size)
  |> Enum.each(fn chunk ->
    action.handle.(chunk)
  end)

  :ok
end
```

### Row Selectability

Some rows shouldn't be selectable (e.g., admin users):

```elixir
defmodule MyApp.Tables.UsersTable do
  use NbFlop.Table

  def selectable?(user, _conn) do
    not user.is_admin
  end
end
```

This is evaluated per-row and added to data:
```elixir
%{id: 1, name: "Admin", _selectable: false}
%{id: 2, name: "User", _selectable: true}
```

---

## Export System

### Export Definition

```elixir
defmodule NbFlop.Export do
  defstruct [
    :name,
    :label,
    :format,        # :csv | :excel | :pdf
    :columns,       # Override which columns to export
    :format_column, # Per-column formatting
    :filename,      # Custom filename generator
    :authorize,     # Authorization callback
    :queue          # Queue large exports
  ]
end
```

### Export Flow

```
User clicks "Export CSV"
  │
  ├─→ Frontend: GET /nb-flop/export?token=...&format=csv&filters=...&selected_ids=...
  │
  ├─→ Backend: Verify token, authorize export
  │
  ├─→ Backend: Load data (respecting filters + selection)
  │
  ├─→ Backend: Transform data through export columns
  │
  ├─→ Backend: Generate file (CSV, Excel, PDF)
  │
  └─→ Response: File download
```

### Export Controller

```elixir
def export(conn, %{"token" => token, "format" => format} = params) do
  with {:ok, %{table: table}} <- NbFlop.Token.verify(token),
       export <- find_export(table, format),
       :ok <- authorize_export(export, conn),
       rows <- load_export_rows(table, params),
       {:ok, binary, content_type, filename} <- generate_export(export, rows, table) do
    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, binary)
  end
end
```

### CSV Exporter

```elixir
defmodule NbFlop.Exporters.CSV do
  def generate(rows, columns, opts) do
    header = Enum.map(columns, & &1.export_label || &1.label)

    data_rows = Enum.map(rows, fn row ->
      Enum.map(columns, fn col ->
        value = Map.get(row, col.key)
        format_value(value, col, opts)
      end)
    end)

    [header | data_rows]
    |> CSV.encode()
    |> Enum.to_list()
    |> IO.iodata_to_binary()
  end
end
```

---

## Table DSL Implementation

### Module Structure

```elixir
defmodule NbFlop.Table do
  defmacro __using__(opts) do
    quote do
      import NbFlop.Table.DSL

      @behaviour NbFlop.Table.Behaviour

      Module.register_attribute(__MODULE__, :nb_flop_resource, accumulate: false)
      Module.register_attribute(__MODULE__, :nb_flop_columns, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_filters, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_actions, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_bulk_actions, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_exports, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_flop_config, accumulate: false)

      @before_compile NbFlop.Table.Compiler
    end
  end
end
```

### DSL Macros

```elixir
defmodule NbFlop.Table.DSL do
  defmacro resource(module) do
    quote do
      @nb_flop_resource unquote(module)
    end
  end

  defmacro columns(do: block) do
    quote do
      import NbFlop.Table.DSL.Columns
      unquote(block)
    end
  end

  defmacro text_column(key, opts \\ []) do
    quote do
      @nb_flop_columns NbFlop.Columns.Text.new(unquote(key), unquote(opts))
    end
  end

  defmacro badge_column(key, opts \\ []) do
    quote do
      @nb_flop_columns NbFlop.Columns.Badge.new(unquote(key), unquote(opts))
    end
  end

  # ... more column macros

  defmacro action(name, opts \\ []) do
    quote do
      @nb_flop_actions NbFlop.Action.new(unquote(name), unquote(opts))
    end
  end
end
```

### Example Table Definition

```elixir
defmodule MyAppWeb.Tables.UsersTable do
  use NbFlop.Table

  # Resource configuration
  resource MyApp.Accounts.User
  flop_schema MyApp.Accounts.User  # For Flop.Schema

  # Table settings
  config do
    name "users"
    default_sort {:name, :asc}
    default_per_page 25
    per_page_options [10, 25, 50, 100]
    sticky_header true
    searchable [:name, :email]
  end

  # Column definitions
  columns do
    text_column :name,
      sortable: true,
      searchable: true

    text_column :email,
      sortable: true,
      searchable: true,
      clickable: fn user -> "mailto:#{user.email}" end

    badge_column :status,
      sortable: true,
      colors: %{
        "active" => :success,
        "pending" => :warning,
        "inactive" => :danger
      }

    numeric_column :orders_count,
      sortable: true,
      label: "Orders"

    date_column :created_at,
      sortable: true,
      format: "MMM d, yyyy"

    boolean_column :verified

    image_column :avatar,
      width: 40,
      height: 40,
      rounded: true

    action_column()
  end

  # Filter definitions
  filters do
    text_filter :name,
      clauses: [:contains, :starts_with, :equals]

    text_filter :email,
      clauses: [:contains, :equals]

    set_filter :status,
      options: [
        {"active", "Active"},
        {"pending", "Pending"},
        {"inactive", "Inactive"}
      ]

    boolean_filter :verified

    date_filter :created_at,
      clauses: [:equals, :greater_than, :less_than, :between]
  end

  # Row actions
  actions do
    action :view,
      url: fn user -> ~p"/users/#{user}" end,
      icon: "EyeIcon"

    action :edit,
      url: fn user -> ~p"/users/#{user}/edit" end,
      icon: "PencilIcon"

    action :delete,
      handle: fn user -> MyApp.Accounts.delete_user(user) end,
      icon: "TrashIcon",
      variant: :danger,
      disabled: fn user -> user.is_admin end,
      hidden: fn user, conn -> not can?(conn, :delete, user) end,
      confirmation: %{
        title: "Delete User",
        message: "Are you sure you want to delete this user?",
        confirm_button: "Delete",
        variant: :danger
      }
  end

  # Bulk actions
  bulk_actions do
    bulk_action :delete_selected,
      handle: fn users -> Enum.each(users, &MyApp.Accounts.delete_user/1) end,
      confirmation: %{
        title: "Delete Users",
        message: "Are you sure you want to delete {count} users?"
      },
      authorize: fn conn -> admin?(conn) end

    bulk_action :export_selected,
      frontend: true  # Handled on frontend, triggers export
  end

  # Exports
  exports do
    export :csv,
      columns: [:name, :email, :status, :created_at]

    export :excel,
      columns: [:name, :email, :status, :orders_count, :created_at],
      format_column: %{
        created_at: fn dt -> Calendar.strftime(dt, "%Y-%m-%d") end
      }
  end

  # Empty state
  empty_state do
    title "No users found"
    message "Get started by creating your first user."
    icon "UsersIcon"
    action "Create User", ~p"/users/new", variant: :primary
  end

  # Views (saved table states)
  views do
    enabled true
    scope_user true
    user_resolver fn conn -> conn.assigns.current_user.id end
  end

  # Row selectability for bulk actions
  def selectable?(user, _conn) do
    not user.is_admin
  end

  # Custom row transformation
  def transform_row(user, data, _conn) do
    Map.put(data, :full_name, "#{user.first_name} #{user.last_name}")
  end
end
```

---

## Frontend Architecture

### Table Component Structure

```tsx
interface TableProps<T> {
  resource: TableResource<T>;
  slots?: {
    topbar?: React.ReactNode;
    filters?: React.ReactNode;
    empty?: React.ReactNode;
    footer?: React.ReactNode;
  };
}

function Table<T>({ resource, slots }: TableProps<T>) {
  const table = useTable(resource);
  const actions = useActions(resource);

  return (
    <div className="nb-flop-table">
      {/* Top bar: search, filters, views, column toggle, export */}
      <TableTopbar table={table} actions={actions} slots={slots?.topbar} />

      {/* Active filters display */}
      {table.hasFilters && (
        <FilterBar
          filters={table.activeFilters}
          onRemove={table.removeFilter}
          onClear={table.clearFilters}
        />
      )}

      {/* Bulk action bar (shown when items selected) */}
      {actions.hasSelection && (
        <BulkActionBar
          actions={resource.bulkActions}
          selectedCount={actions.selectedCount}
          totalCount={resource.meta.totalCount}
          onAction={actions.executeBulkAction}
          onClear={actions.clearSelection}
        />
      )}

      {/* Table content */}
      {resource.data.length === 0 ? (
        slots?.empty || <EmptyState config={resource.emptyState} />
      ) : (
        <TableContent
          columns={resource.columns}
          data={resource.data}
          table={table}
          actions={actions}
          stickyHeader={resource.stickyHeader}
        />
      )}

      {/* Footer: pagination, per-page select */}
      <TableFooter table={table} meta={resource.meta} />
    </div>
  );
}
```

### useTable Hook

```tsx
function useTable<T>(resource: TableResource<T>) {
  const [state, setState] = useState(resource.state);

  // URL sync
  useEffect(() => {
    const params = stateToQueryParams(state, resource.name);
    router.visit(window.location.pathname, {
      data: params,
      preserveState: true,
      preserveScroll: true,
      only: [resource.name]
    });
  }, [state]);

  return {
    // State
    state,
    columns: resource.columns,
    visibleColumns: resource.columns.filter(c => state.columns.includes(c.key)),

    // Sorting
    sort: state.sort,
    setSort: (field: string, direction: 'asc' | 'desc') => {
      setState(s => ({ ...s, sort: { field, direction }, page: 1 }));
    },
    toggleSort: (field: string) => {
      const current = state.sort;
      if (current?.field !== field) {
        setState(s => ({ ...s, sort: { field, direction: 'asc' }, page: 1 }));
      } else if (current.direction === 'asc') {
        setState(s => ({ ...s, sort: { field, direction: 'desc' }, page: 1 }));
      } else {
        setState(s => ({ ...s, sort: null, page: 1 }));
      }
    },

    // Filtering
    filters: state.filters,
    hasFilters: state.filters.length > 0,
    setFilter: (field, op, value) => {
      setState(s => ({
        ...s,
        filters: [...s.filters.filter(f => f.field !== field), { field, op, value }],
        page: 1
      }));
    },
    removeFilter: (field) => {
      setState(s => ({
        ...s,
        filters: s.filters.filter(f => f.field !== field),
        page: 1
      }));
    },
    clearFilters: () => {
      setState(s => ({ ...s, filters: [], page: 1 }));
    },

    // Search
    search: state.search,
    setSearch: (value: string) => {
      setState(s => ({ ...s, search: value, page: 1 }));
    },

    // Pagination
    page: state.page,
    perPage: state.perPage,
    setPage: (page: number) => {
      setState(s => ({ ...s, page }));
    },
    setPerPage: (perPage: number) => {
      setState(s => ({ ...s, perPage, page: 1 }));
    },

    // Columns
    toggleColumn: (key: string) => {
      setState(s => ({
        ...s,
        columns: s.columns.includes(key)
          ? s.columns.filter(k => k !== key)
          : [...s.columns, key]
      }));
    },

    // Views
    views: resource.views,
    loadView: (view: View) => {
      setState(view.state);
    },
    saveView: async (name: string) => {
      await fetch('/nb-flop/views', {
        method: 'POST',
        body: JSON.stringify({
          token: resource.token,
          name,
          state
        })
      });
      router.reload({ only: [resource.name] });
    }
  };
}
```

### useActions Hook

```tsx
function useActions<T>(resource: TableResource<T>) {
  const [selection, setSelection] = useState<Selection>({ mode: 'explicit', ids: new Set() });
  const [executing, setExecuting] = useState<string | null>(null);

  return {
    // Selection
    selection,
    selectedCount: selection.mode === 'all'
      ? resource.meta.totalCount - selection.ids.size
      : selection.ids.size,
    hasSelection: selection.mode === 'all' || selection.ids.size > 0,

    isSelected: (id: string) => {
      if (selection.mode === 'all') return !selection.ids.has(id);
      return selection.ids.has(id);
    },

    toggleItem: (id: string) => {
      setSelection(s => {
        const newIds = new Set(s.ids);
        if (s.mode === 'explicit') {
          if (newIds.has(id)) newIds.delete(id);
          else newIds.add(id);
        } else {
          // all or all_except mode
          if (newIds.has(id)) newIds.delete(id);
          else newIds.add(id);
        }
        return { ...s, ids: newIds };
      });
    },

    selectAll: () => {
      setSelection({ mode: 'all', ids: new Set() });
    },

    clearSelection: () => {
      setSelection({ mode: 'explicit', ids: new Set() });
    },

    // Actions
    executing,

    executeAction: async (action: Action, row: T) => {
      // Check if action has URL (it's a link, not a handler)
      const rowAction = row._actions[action.name];
      if (rowAction.url) {
        router.visit(rowAction.url);
        return;
      }

      // It's a handler action
      setExecuting(action.name);
      try {
        const response = await fetch('/nb-flop/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            token: resource.token,
            action: action.name,
            id: row.id
          })
        });
        const result = await response.json();
        if (result.success) {
          router.reload({ only: [resource.name], preserveScroll: true });
        } else {
          // Show error toast
        }
      } finally {
        setExecuting(null);
      }
    },

    executeBulkAction: async (action: BulkAction) => {
      setExecuting(action.name);
      try {
        const response = await fetch('/nb-flop/bulk-action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            token: resource.token,
            action: action.name,
            selection: {
              mode: selection.mode,
              ids: Array.from(selection.ids)
            },
            // Include current filters for "all" mode
            filters: resource.state.filters
          })
        });
        const result = await response.json();
        if (result.success) {
          setSelection({ mode: 'explicit', ids: new Set() });
          router.reload({ only: [resource.name], preserveScroll: true });
        }
      } finally {
        setExecuting(null);
      }
    }
  };
}
```

---

## Key Differences from Initial Plan

| Aspect | Initial Plan | Revised Plan |
|--------|--------------|--------------|
| Action state | Global action definitions | Per-row action evaluation (`_actions` in row data) |
| Token security | Mentioned briefly | Detailed Phoenix.Token implementation |
| Bulk selection | Not detailed | Explicit vs all modes, selectability per row |
| Resource structure | Incomplete | Full serialization spec with all fields |
| Views persistence | Basic | Full schema, CRUD endpoints, scoping |
| Column transformation | Separate from serialization | Integrated into row transformation pipeline |
| Export flow | Basic | Complete with chunking, queueing option |
| Frontend architecture | Basic Table component | Full useTable + useActions hooks |

---

## Implementation Order

### Phase 1: Core Table Infrastructure
1. `NbFlop.Table` macro and DSL
2. Column structs and transformations
3. `Table.make/2` with Flop integration
4. `TableSerializer` for resource output
5. Basic frontend `<Table>` component

### Phase 2: Actions System
1. Action struct with handlers
2. Per-row action evaluation
3. Token generation/verification
4. Action controller endpoint
5. Frontend action execution

### Phase 3: Bulk Actions
1. Bulk action struct
2. Selection modes (explicit, all, all_except)
3. `selectable?/2` callback
4. Bulk action controller
5. Frontend selection + bulk bar

### Phase 4: Filters & Columns
1. Filter types (text, set, date, numeric, boolean)
2. Column toggle state
3. Column visibility persistence
4. Frontend filter components

### Phase 5: Views & Export
1. Views database schema + migration
2. Views CRUD controller
3. Export system (CSV, Excel)
4. Frontend views dropdown
5. Frontend export button

### Phase 6: Polish
1. Empty state component
2. Sticky header/columns CSS
3. Dark mode support
4. Translations
5. Documentation

---

## Open Questions

1. **Vue support**: Priority for Vue components alongside React?

2. **Async exports**: Use Oban for large exports? Notification mechanism?

3. **Real-time updates**: Phoenix channels for live table updates?

4. **Authorization framework**: Integrate with existing auth (Bodyguard, Canada)?

5. **Custom column types**: Plugin system for new column types?
