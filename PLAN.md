# nb_flop Feature Expansion Plan

## Executive Summary

This plan outlines how to expand nb_flop to match the comprehensive features of Inertia Table (Laravel). The goal is to provide a declarative, type-safe data table solution for Phoenix/Inertia.js that rivals the Laravel package while staying true to Elixir idioms.

## Current State of nb_flop

### What We Have
- **Backend**: Serializers for Flop.Meta, Flop.Filter, FlopParams, FilterableField
- **Frontend**: React components (Pagination, CursorPagination, SortableHeader, FilterForm, DataTable)
- **Hook**: `useFlopParams` for state management
- **Integration**: TanStack Table wrapper, Linear-style filter components

### What's Missing (vs Inertia Table)
1. **Column System**: No declarative column types/definitions on backend
2. **Row Actions**: No action system with confirmation dialogs
3. **Bulk Actions**: No bulk selection and actions
4. **Row Links**: No URL object abstraction
5. **Exporting**: No export functionality
6. **Toggle Columns**: No column visibility management
7. **Sticky Columns/Header**: No sticky positioning
8. **Views/Bookmarks**: No saved table states
9. **Empty State**: No declarative empty state
10. **Multiple Tables**: Limited support
11. **Table DSL**: No declarative table definition
12. **Anonymous Tables**: No inline table building
13. **Transformations**: Limited model transformation

---

## Architecture Decision: Table DSL vs Flop Extension

### Option A: Extend Flop (Recommended)
Keep Flop as the query layer, add a Table DSL layer on top.

```
User Request → Table DSL → Flop Query → Database
                  ↓
           Column/Action/Export Metadata
                  ↓
           Frontend Components
```

**Pros:**
- Leverages Flop's mature query capabilities
- Clear separation of concerns
- Easier migration for existing Flop users

### Option B: Replace Flop
Build custom query layer integrated with Table DSL.

**Cons:**
- Duplicates Flop functionality
- More maintenance burden
- Not recommended

**Decision: Option A** - Build a Table DSL that wraps Flop.

---

## Phase 1: Table DSL Foundation

### 1.1 Table Module DSL

Create a declarative table definition system:

```elixir
defmodule MyAppWeb.Tables.UsersTable do
  use NbFlop.Table

  table do
    resource User
    default_sort :name
    default_per_page 25
    per_page_options [10, 25, 50, 100]

    # Columns
    columns do
      text_column :name, sortable: true, searchable: true
      text_column :email, sortable: true, searchable: true
      badge_column :status, colors: %{active: :success, inactive: :danger}
      numeric_column :orders_count, sortable: true
      date_column :created_at, format: "MMM d, yyyy"
      boolean_column :verified
      image_column :avatar, width: 40, height: 40, rounded: true
      action_column()
    end

    # Filters
    filters do
      text_filter :name
      set_filter :status, options: [:active, :inactive, :pending]
      date_filter :created_at
      boolean_filter :verified
    end

    # Actions
    actions do
      action :edit, fn user -> "/users/#{user.id}/edit" end
      action :delete,
        handle: fn user -> Users.delete(user) end,
        confirmation: [
          title: "Delete User",
          message: "Are you sure?",
          variant: :danger
        ]
    end

    # Bulk Actions
    bulk_actions do
      bulk_action :delete_selected,
        handle: fn users -> Enum.each(users, &Users.delete/1) end,
        confirmation: true
      bulk_action :export_selected,
        frontend: true
    end

    # Exports
    exports do
      export :csv
      export :excel
    end

    # Empty State
    empty_state do
      title "No users found"
      message "Get started by creating your first user."
      action "Create User", "/users/new", variant: :primary
    end

    # Views (Saved States)
    views enabled: true, scope_user: true
  end
end
```

### 1.2 Column Types

Define column type modules:

```elixir
# lib/nb_flop/columns/text_column.ex
defmodule NbFlop.Columns.TextColumn do
  defstruct [
    :key,
    :label,
    :sortable,
    :searchable,
    :toggleable,
    :visible,
    :alignment,
    :wrap,
    :truncate,
    :header_class,
    :cell_class,
    :clickable,
    :meta,
    :map_as
  ]
end

# All column types:
# - TextColumn
# - BadgeColumn (with colors map)
# - NumericColumn (with prefix, suffix, decimals, thousands_separator)
# - DateColumn (with format)
# - DateTimeColumn (with format)
# - BooleanColumn
# - ImageColumn (with disk, width, height, rounded, fallback)
# - ActionColumn (for row actions)
```

### 1.3 Column Serializer

Generate TypeScript-compatible column metadata:

```elixir
defmodule NbFlop.ColumnSerializer do
  use NbSerializer.Serializer

  schema do
    field :key, :string
    field :type, enum: ["text", "badge", "numeric", "date", "datetime", "boolean", "image", "action"]
    field :label, :string
    field :sortable, :boolean
    field :searchable, :boolean
    field :toggleable, :boolean
    field :visible, :boolean
    field :alignment, enum: ["left", "center", "right"]
    field :meta, :any, optional: true

    # Type-specific fields
    field :colors, :any, optional: true  # BadgeColumn
    field :prefix, :string, optional: true  # NumericColumn
    field :suffix, :string, optional: true
    field :decimals, :number, optional: true
    field :format, :string, optional: true  # Date columns
    field :width, :number, optional: true  # ImageColumn
    field :height, :number, optional: true
    field :rounded, :boolean, optional: true
  end
end
```

---

## Phase 2: Actions System

### 2.1 Row Actions

```elixir
defmodule NbFlop.Action do
  defstruct [
    :name,
    :label,
    :url,           # Function to generate URL
    :handle,        # Function to handle action
    :icon,
    :variant,       # :default, :danger, :success, :warning, :info
    :disabled,      # Function returning boolean
    :hidden,        # Function returning boolean
    :confirmation,  # Confirmation options
    :frontend,      # Frontend-only action
    :data_attributes,
    :success_message,
    :error_message
  ]
end

# Confirmation struct
defmodule NbFlop.Confirmation do
  defstruct [
    :enabled,
    :title,
    :message,
    :confirm_button,
    :cancel_button,
    :icon,
    :variant
  ]
end
```

### 2.2 Action Routes

Add action routes to handle server-side actions:

```elixir
# In user's router.ex
scope "/nb-flop", NbFlop.Controller do
  post "/action/:table/:action", ActionController, :execute
  post "/bulk-action/:table/:action", ActionController, :execute_bulk
end
```

### 2.3 Frontend Action Components

```tsx
// ActionDropdown.tsx
interface ActionDropdownProps {
  actions: Action[];
  item: unknown;
  onAction: (action: Action, item: unknown) => void;
}

// ConfirmationDialog.tsx
interface ConfirmationDialogProps {
  open: boolean;
  title: string;
  message: string;
  variant: 'default' | 'danger' | 'warning';
  onConfirm: () => void;
  onCancel: () => void;
}

// BulkActionBar.tsx
interface BulkActionBarProps {
  selectedCount: number;
  totalCount: number;
  actions: BulkAction[];
  onAction: (action: BulkAction) => void;
  onClearSelection: () => void;
}
```

---

## Phase 3: URL Object System

### 3.1 URL Builder

Port the Inertia Table URL concept:

```elixir
defmodule NbFlop.Url do
  defstruct [
    :href,
    :method,
    :preserve_scroll,
    :preserve_state,
    :open_in_new_tab,
    :as_download,
    :disabled,
    :hidden,
    :modal,
    :signed
  ]

  def new(href), do: %__MODULE__{href: href}
  def route(name, params), do: %__MODULE__{href: route_helper(name, params)}
  def preserve_scroll(url), do: %{url | preserve_scroll: true}
  def preserve_state(url), do: %{url | preserve_state: true}
  def open_in_new_tab(url), do: %{url | open_in_new_tab: true}
  def as_download(url), do: %{url | as_download: true}
  def modal(url, opts \\ []), do: %{url | modal: opts}
  def signed(url, expires_in \\ nil), do: %{url | signed: {true, expires_in}}

  def when(url, condition, if_true, if_false \\ & &1) do
    if condition, do: if_true.(url), else: if_false.(url)
  end
end
```

### 3.2 URL Serializer

```elixir
defmodule NbFlop.UrlSerializer do
  use NbSerializer.Serializer

  schema do
    field :href, :string
    field :method, enum: ["get", "post", "put", "patch", "delete"], optional: true
    field :preserve_scroll, :boolean, optional: true
    field :preserve_state, :boolean, optional: true
    field :open_in_new_tab, :boolean, optional: true
    field :as_download, :boolean, optional: true
    field :disabled, :boolean, optional: true
    field :hidden, :boolean, optional: true
    field :modal, :any, optional: true
  end
end
```

---

## Phase 4: Export System

### 4.1 Export Module

```elixir
defmodule NbFlop.Export do
  defstruct [
    :name,
    :format,        # :csv, :excel, :pdf
    :columns,       # Column mapping
    :format_column, # Per-column formatting
    :style_column,  # Per-column styling (Excel)
    :using,         # Custom export class
    :queue,         # Queue export for large datasets
    :authorize      # Authorization function
  ]
end

defmodule NbFlop.Exporter do
  @callback export(data :: list(), columns :: list(), opts :: keyword()) :: binary()
end

defmodule NbFlop.Exporters.CSV do
  @behaviour NbFlop.Exporter

  def export(data, columns, opts) do
    # Generate CSV
  end
end

defmodule NbFlop.Exporters.Excel do
  @behaviour NbFlop.Exporter
  # Requires xlsxir or similar dependency
end
```

### 4.2 Export Routes

```elixir
scope "/nb-flop", NbFlop.Controller do
  get "/export/:table/:format", ExportController, :export
end
```

### 4.3 Frontend Export Button

```tsx
// ExportButton.tsx
interface ExportButtonProps {
  exports: Export[];
  tableUrl: string;
  currentParams: FlopParams;
  selectedIds?: string[];
}
```

---

## Phase 5: Column Visibility & Sticky

### 5.1 Column Toggle System

Backend state management:

```elixir
defmodule NbFlop.ColumnState do
  defstruct [:visible_columns, :column_order]

  def toggle(state, column_key) do
    # Toggle visibility
  end

  def reorder(state, from_index, to_index) do
    # Reorder columns
  end
end
```

Frontend components:

```tsx
// ColumnToggle.tsx
interface ColumnToggleProps {
  columns: Column[];
  visibleColumns: string[];
  onToggle: (columnKey: string) => void;
  onReorder?: (fromIndex: number, toIndex: number) => void;
}
```

### 5.2 Sticky Columns/Header

Add sticky configuration to table:

```elixir
table do
  sticky_header true

  columns do
    text_column :name, stickable: true
    # ...
  end
end
```

Frontend CSS classes:

```css
.nb-flop-sticky-header thead {
  position: sticky;
  top: 0;
  z-index: 10;
}

.nb-flop-sticky-column {
  position: sticky;
  left: 0;
  z-index: 5;
}
```

---

## Phase 6: Views (Saved Table States)

### 6.1 Database Migration

```elixir
defmodule NbFlop.Migrations.CreateTableViews do
  use Ecto.Migration

  def change do
    create table(:nb_flop_views, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :table_name, :string, null: false
      add :user_id, :string
      add :state, :map, null: false
      add :is_default, :boolean, default: false
      add :shared, :boolean, default: false
      timestamps()
    end

    create index(:nb_flop_views, [:table_name])
    create index(:nb_flop_views, [:user_id])
  end
end
```

### 6.2 Views Configuration

```elixir
defmodule NbFlop.Views do
  defstruct [
    :enabled,
    :scope_user,
    :user_resolver,
    :attributes,
    :scope_table_name,
    :model_class
  ]

  def make(opts \\ []) do
    %__MODULE__{
      enabled: true,
      scope_user: Keyword.get(opts, :scope_user, true),
      user_resolver: Keyword.get(opts, :user_resolver),
      attributes: Keyword.get(opts, :attributes, %{}),
      scope_table_name: Keyword.get(opts, :scope_table_name, true)
    }
  end
end
```

### 6.3 Frontend Views Component

```tsx
// ViewsDropdown.tsx
interface ViewsDropdownProps {
  views: View[];
  currentView?: View;
  onSelectView: (view: View) => void;
  onSaveView: (name: string) => void;
  onUpdateView: (view: View) => void;
  onDeleteView: (view: View) => void;
}
```

---

## Phase 7: Empty State

### 7.1 Empty State Configuration

```elixir
defmodule NbFlop.EmptyState do
  defstruct [
    :title,
    :message,
    :icon,
    :action_label,
    :action_url,
    :action_variant,
    :action_icon,
    :data_attributes,
    :meta
  ]
end
```

### 7.2 Frontend Empty State Component

```tsx
// EmptyState.tsx
interface EmptyStateProps {
  config: EmptyStateConfig;
  hasFilters: boolean;
  onClearFilters?: () => void;
}

function EmptyState({ config, hasFilters, onClearFilters }: EmptyStateProps) {
  return (
    <div className="nb-flop-empty-state">
      {config.icon && <Icon name={config.icon} />}
      <h3>{config.title}</h3>
      <p>{config.message}</p>
      {hasFilters && onClearFilters && (
        <button onClick={onClearFilters}>Clear filters</button>
      )}
      {config.action && (
        <Link href={config.action.url} className={`nb-flop-button-${config.action.variant}`}>
          {config.action.label}
        </Link>
      )}
    </div>
  );
}
```

---

## Phase 8: Enhanced DataTable Component

### 8.1 Unified Table Component

Create a comprehensive table component that combines all features:

```tsx
// Table.tsx
interface TableProps<T> {
  // Core
  resource: TableResource<T>;

  // Rendering
  emptyState?: React.ReactNode;
  loading?: boolean;

  // Callbacks
  onRowClick?: (row: T) => void;

  // Slots
  slots?: {
    topbar?: React.ReactNode;
    filters?: React.ReactNode;
    thead?: React.ReactNode;
    tbody?: React.ReactNode;
    footer?: React.ReactNode;
    loading?: React.ReactNode;
  };
}

interface TableResource<T> {
  data: T[];
  meta: FlopMeta;
  columns: Column[];
  actions?: Action[];
  bulkActions?: BulkAction[];
  exports?: Export[];
  emptyState?: EmptyStateConfig;
  views?: View[];
  state: TableState;
}
```

### 8.2 useTable Hook

Comprehensive hook for table state:

```tsx
// useTable.ts
interface UseTableReturn<T> {
  // Data
  data: T[];
  meta: FlopMeta;
  columns: Column[];
  visibleColumns: Column[];

  // State
  state: TableState;
  isLoading: boolean;
  isNavigating: boolean;

  // Sorting
  setSort: (field: string, direction: SortDirection) => void;
  toggleSort: (field: string) => void;
  getSortDirection: (field: string) => SortDirection;

  // Filtering
  filters: FlopFilter[];
  hasFilters: boolean;
  setFilter: (field: string, op: string, value: unknown) => void;
  removeFilter: (field: string, op?: string) => void;
  clearFilters: () => void;

  // Pagination
  setPage: (page: number) => void;
  setPerPage: (perPage: number) => void;

  // Columns
  toggleColumn: (key: string) => void;
  reorderColumns: (from: number, to: number) => void;

  // Selection
  selectedItems: T[];
  isSelected: (item: T) => boolean;
  toggleSelection: (item: T) => void;
  selectAll: () => void;
  clearSelection: () => void;
  allSelected: boolean;
  someSelected: boolean;

  // Views
  views: View[];
  currentView?: View;
  saveView: (name: string) => void;
  loadView: (view: View) => void;
  deleteView: (view: View) => void;

  // Actions
  performAction: (action: Action, item: T) => Promise<void>;
  performBulkAction: (action: BulkAction) => Promise<void>;

  // Export
  exportData: (format: string) => void;

  // Navigation
  visitTableUrl: (params: Partial<FlopParams>) => void;
}
```

---

## Phase 9: Anonymous Table Builder

### 9.1 Inline Table Definition

```elixir
defmodule NbFlop.Builder do
  def build(opts) do
    %NbFlop.Table{
      resource: opts[:resource],
      columns: opts[:columns] || [],
      filters: opts[:filters] || [],
      search: opts[:search],
      name: opts[:name],
      pagination: opts[:pagination] || true,
      per_page_options: opts[:per_page_options] || [10, 25, 50],
      default_sort: opts[:default_sort],
      default_per_page: opts[:default_per_page] || 25,
      sticky_header: opts[:sticky_header] || false,
      empty_state: opts[:empty_state],
      transform_model: opts[:transform_model]
    }
  end
end

# Usage in controller:
render_inertia(conn, :users_index,
  users: NbFlop.build(
    resource: User,
    columns: [
      NbFlop.Columns.text(:name, sortable: true),
      NbFlop.Columns.text(:email, sortable: true),
      NbFlop.Columns.badge(:status, colors: %{active: :success}),
    ],
    filters: [
      NbFlop.Filters.text(:name),
      NbFlop.Filters.set(:status, options: [:active, :inactive]),
    ],
    search: [:name, :email],
    default_sort: :name
  )
)
```

---

## Phase 10: Integration & Polish

### 10.1 nb_inertia Modal Integration

```elixir
# In action definition
action :edit, fn user, url ->
  url
  |> NbFlop.Url.route(:users_edit, user)
  |> NbFlop.Url.modal(slideover: true, size: :lg)
end
```

### 10.2 nb_routes Integration

```elixir
# Automatic route detection
action :edit, fn user ->
  Routes.edit_user_path(user)  # Auto-detected method
end
```

### 10.3 Dark Mode Support

```tsx
// setDarkModeStrategy.ts
export function setDarkModeStrategy(strategy: 'media' | 'selector' | (() => boolean)) {
  // Configure dark mode detection
}
```

### 10.4 Translations

```tsx
// translations.ts
export function setTranslations(translations: Partial<TableTranslations>) {
  // Merge with defaults
}

interface TableTranslations {
  no_rows_selected: string;
  selected_rows: string | ((params: { count: number; total: number }) => string);
  clear_filters: string;
  // ... more keys
}
```

---

## Implementation Priority

### Phase 1: Foundation (Week 1-2)
1. Table DSL with `use NbFlop.Table`
2. Column types (Text, Badge, Numeric, Date, Boolean, Image)
3. Column serializer
4. Basic Table component integration

### Phase 2: Actions (Week 3)
1. Row actions with URL support
2. Confirmation dialogs
3. Action routes and handlers
4. Frontend action components

### Phase 3: Bulk & Export (Week 4)
1. Bulk actions
2. Row selection
3. Export system (CSV, Excel)
4. Export routes

### Phase 4: State Management (Week 5)
1. Column visibility toggle
2. Views (saved states)
3. Database migration for views
4. Views UI components

### Phase 5: Polish (Week 6)
1. Empty state
2. Sticky columns/header
3. Anonymous table builder
4. nb_inertia modal integration
5. Translations
6. Dark mode
7. Documentation

---

## File Structure After Implementation

```
nb_flop/
├── lib/
│   ├── nb_flop.ex
│   ├── nb_flop/
│   │   ├── table.ex              # Table DSL
│   │   ├── builder.ex            # Anonymous builder
│   │   ├── columns/
│   │   │   ├── column.ex         # Base column
│   │   │   ├── text_column.ex
│   │   │   ├── badge_column.ex
│   │   │   ├── numeric_column.ex
│   │   │   ├── date_column.ex
│   │   │   ├── datetime_column.ex
│   │   │   ├── boolean_column.ex
│   │   │   ├── image_column.ex
│   │   │   └── action_column.ex
│   │   ├── filters/
│   │   │   ├── filter.ex
│   │   │   ├── text_filter.ex
│   │   │   ├── numeric_filter.ex
│   │   │   ├── set_filter.ex
│   │   │   ├── date_filter.ex
│   │   │   └── boolean_filter.ex
│   │   ├── actions/
│   │   │   ├── action.ex
│   │   │   ├── bulk_action.ex
│   │   │   ├── confirmation.ex
│   │   │   └── url.ex
│   │   ├── exports/
│   │   │   ├── export.ex
│   │   │   ├── csv_exporter.ex
│   │   │   └── excel_exporter.ex
│   │   ├── views/
│   │   │   ├── view.ex
│   │   │   └── view_schema.ex
│   │   ├── serializers/
│   │   │   ├── table_serializer.ex
│   │   │   ├── column_serializer.ex
│   │   │   ├── action_serializer.ex
│   │   │   ├── url_serializer.ex
│   │   │   └── empty_state_serializer.ex
│   │   ├── controller/
│   │   │   ├── action_controller.ex
│   │   │   ├── export_controller.ex
│   │   │   └── views_controller.ex
│   │   └── empty_state.ex
│   └── mix/
│       └── tasks/
│           └── nb_flop.install.ex
├── priv/
│   ├── components/
│   │   ├── base-ui/flop/
│   │   │   ├── Table.tsx           # Main component
│   │   │   ├── useTable.ts         # Comprehensive hook
│   │   │   ├── useActions.ts       # Action management
│   │   │   ├── columns/
│   │   │   │   ├── TextCell.tsx
│   │   │   │   ├── BadgeCell.tsx
│   │   │   │   ├── NumericCell.tsx
│   │   │   │   ├── DateCell.tsx
│   │   │   │   ├── BooleanCell.tsx
│   │   │   │   ├── ImageCell.tsx
│   │   │   │   └── ActionCell.tsx
│   │   │   ├── ActionDropdown.tsx
│   │   │   ├── BulkActionBar.tsx
│   │   │   ├── ConfirmationDialog.tsx
│   │   │   ├── ColumnToggle.tsx
│   │   │   ├── ViewsDropdown.tsx
│   │   │   ├── ExportButton.tsx
│   │   │   ├── EmptyState.tsx
│   │   │   ├── ... (existing components)
│   │   │   └── index.ts
│   │   └── radix-ui/flop/
│   │       └── ... (same structure)
│   └── migrations/
│       └── create_table_views.ex
└── test/
    └── ...
```

---

## Key Differences from Inertia Table

| Feature | Inertia Table (Laravel) | nb_flop (Planned) |
|---------|------------------------|-------------------|
| Query Layer | Eloquent | Flop |
| Column Definition | PHP DSL | Elixir DSL |
| Type Generation | Manual | nb_ts (automatic) |
| Frontend Framework | Vue/React | React (Vue planned) |
| Route Integration | Laravel Routes | nb_routes |
| Modal Integration | Inertia Modal | nb_inertia modals |
| Component Style | npm package | Copy-to-codebase |

---

## Migration Strategy for Existing Users

1. **Serializers remain compatible** - Existing FlopMetaSerializer continues to work
2. **Components are additive** - New components don't replace existing ones
3. **Table DSL is optional** - Can still use Flop directly without Table DSL
4. **Incremental adoption** - Start with basic features, add advanced ones as needed

---

## Next Steps

1. Review and approve this plan
2. Create issues in bd for tracking
3. Begin Phase 1 implementation
4. Set up test application for validation
