# NbFlop

Flop integration for the nb ecosystem, providing pagination, sorting, and filtering for Phoenix applications with Inertia.js.

## Features

- **Table DSL** - Declarative data tables with the "Table as Resource" pattern
- **Serializers** - Full Flop.Meta serialization with schema introspection
- **React Components** - Pagination, sorting, filtering, and full table components
- **Row Actions** - Per-row actions with confirmation dialogs
- **Bulk Actions** - Selection and batch operations
- **CSV Export** - Export table data to CSV
- **Saved Views** - User-customizable table views

## Installation

Add `nb_flop` to your dependencies:

```elixir
def deps do
  [
    {:nb_flop, "~> 0.1"}
  ]
end
```

### Basic Installation

```bash
mix nb_flop.install
```

### Table DSL Installation (Recommended)

```bash
mix nb_flop.install --table
```

### Options

- `--ui base` - Base UI (unstyled primitives from MUI team)
- `--ui radix` - Radix UI (accessibility-first primitives)
- `--table` - Install Table DSL components and routes
- `--with-views` - Include saved views support
- `--with-exports` - Include CSV export support

---

## Table DSL (Recommended)

The Table DSL provides a "Table as Resource" pattern where the backend is the single source of truth for table configuration.

### Quick Start

#### 1. Create a Table Module

```elixir
defmodule MyAppWeb.Tables.UsersTable do
  use NbFlop.Table

  resource MyApp.Accounts.User
  repo MyApp.Repo

  config do
    name "users"
    default_sort {:name, :asc}
    default_per_page 25
    per_page_options [10, 25, 50, 100]
  end

  columns do
    text_column :name, sortable: true, searchable: true
    text_column :email, sortable: true
    badge_column :status, colors: %{"active" => :success, "inactive" => :danger}
    numeric_column :posts_count, label: "Posts"
    date_column :inserted_at, label: "Joined", sortable: true
    action_column()
  end

  filters do
    text_filter :name, clauses: [:contains, :starts_with, :equals]
    set_filter :status, options: [{"active", "Active"}, {"inactive", "Inactive"}]
  end

  actions do
    action :edit,
      url: fn user -> "/users/#{user.id}/edit" end,
      icon: "PencilIcon"

    action :delete,
      handle: fn user -> MyApp.Accounts.delete_user(user) end,
      icon: "TrashIcon",
      variant: :danger,
      confirmation: %{
        title: "Delete User",
        message: "Are you sure you want to delete #{user.name}?"
      }
  end

  bulk_actions do
    bulk_action :delete,
      handle: fn users -> Enum.each(users, &MyApp.Accounts.delete_user/1) end,
      variant: :danger,
      confirmation: %{
        title: "Delete Users",
        message: "Are you sure you want to delete {count} users?"
      }
  end
end
```

#### 2. Use in Controller

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use NbInertia.Controller

  def index(conn, params) do
    render_inertia(conn, :users_index,
      users: MyAppWeb.Tables.UsersTable.make(conn, params)
    )
  end
end
```

#### 3. Add Routes

```elixir
# In router.ex
use NbFlop.Router

scope "/" do
  pipe_through [:browser]

  nb_flop_routes()  # Adds action, bulk-action, export, and views routes
end
```

#### 4. Use in React

```tsx
import { Table } from '@/components/table';

export default function UsersIndex({ users }) {
  return <Table resource={users} />;
}
```

That's it! The Table component handles sorting, pagination, filtering, row selection, and actions automatically.

### Column Types

```elixir
columns do
  text_column :name, sortable: true, searchable: true
  badge_column :status, colors: %{"active" => :success, "pending" => :warning}
  numeric_column :price, prefix: "$", decimals: 2
  date_column :created_at, format: "MMM d, yyyy"
  datetime_column :updated_at
  boolean_column :active
  image_column :avatar, width: 40, height: 40, rounded: true
  action_column()
end
```

### Filter Types

```elixir
filters do
  text_filter :name, clauses: [:contains, :equals, :starts_with]
  set_filter :status, options: [{"active", "Active"}, {"inactive", "Inactive"}]
  number_filter :price, clauses: [:equals, :gt, :lt, :between]
  date_filter :created_at, clauses: [:equals, :gt, :lt, :between]
  boolean_filter :active
end
```

### Actions

```elixir
actions do
  # URL action - navigates user
  action :view, url: fn row -> "/items/#{row.id}" end

  # Handle action - executes on backend
  action :archive,
    handle: fn row -> MyApp.archive(row) end,
    disabled: fn row -> row.archived end

  # With confirmation
  action :delete,
    handle: fn row -> MyApp.delete(row) end,
    confirmation: %{
      title: "Delete Item",
      message: "This cannot be undone."
    }
end
```

### Bulk Actions

```elixir
bulk_actions do
  bulk_action :export,
    handle: fn rows -> {:ok, "Exported #{length(rows)} rows"} end

  bulk_action :delete,
    handle: fn rows -> Enum.each(rows, &MyApp.delete/1) end,
    chunk_size: 100  # Process in batches
end
```

### Exports

```elixir
exports do
  export :csv,
    format: :csv,
    columns: [:name, :email, :status],
    format_column: %{
      status: fn val -> String.upcase(to_string(val)) end
    }
end
```

### Multiple Tables

Use the `:as` option for multiple tables on the same page:

```elixir
def index(conn, params) do
  render_inertia(conn, :dashboard,
    users: MyAppWeb.Tables.UsersTable.make(conn, params, as: "users"),
    posts: MyAppWeb.Tables.PostsTable.make(conn, params, as: "posts")
  )
end
```

---

## Basic Usage (Manual)

For more control, you can use the serializers and components directly.

### Generated Files

#### Serializers (Elixir)

The installer generates these serializers to your codebase:

- `FlopFilterSerializer` - Serializes `Flop.Filter` structs
- `FlopParamsSerializer` - Serializes Flop query parameters
- `FlopMetaSerializer` - Serializes `Flop.Meta` with schema introspection
- `FilterableFieldSerializer` - Serializes field metadata for frontend

### React Components

Components are copied to `assets/js/components/flop/`:

- `types.ts` - TypeScript type definitions
- `useFlopParams.ts` - Hook for state management
- `Pagination.tsx` - Page-based pagination component
- `CursorPagination.tsx` - Cursor-based pagination component
- `SortableHeader.tsx` - Sortable table header component
- `FilterForm.tsx` - Filter form container with render prop
- `index.ts` - Re-exports all components

## Usage

### 1. Configure Your Schema

Add `@derive Flop.Schema` to your Ecto schemas:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema

  @derive {
    Flop.Schema,
    filterable: [:title, :status, :author_id],
    sortable: [:title, :inserted_at, :published_at]
  }

  schema "posts" do
    field :title, :string
    field :status, Ecto.Enum, values: [:draft, :published]
    field :published_at, :utc_datetime
    belongs_to :author, MyApp.Accounts.User
    timestamps()
  end
end
```

### 2. Use in Your Controller

```elixir
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller
  use NbInertia.Controller

  alias MyApp.Blog.Post
  alias MyAppWeb.Serializers.{PostSerializer, FlopMetaSerializer}

  def index(conn, params) do
    case Flop.validate_and_run(Post, params, for: Post) do
      {:ok, {posts, meta}} ->
        render_inertia(conn, :posts_index,
          posts: {PostSerializer, posts},
          meta: {FlopMetaSerializer, meta, schema: Post}
        )

      {:error, changeset} ->
        # Handle validation error
        conn
        |> put_flash(:error, "Invalid parameters")
        |> redirect(to: ~p"/posts")
    end
  end
end
```

### 3. Use Components in React

```tsx
import { useFlopParams, Pagination, SortableHeader, flopToQueryParams } from '@/components/flop';
import { router } from '@/lib/inertia';
import { posts_path } from '@/routes';

interface PostsIndexProps {
  posts: Post[];
  meta: FlopMeta;
}

export default function PostsIndex({ posts, meta }: PostsIndexProps) {
  const flop = useFlopParams(meta, {
    onParamsChange: (params) => {
      router.visit(posts_path({ query: flopToQueryParams(params) }), {
        preserveState: true,
        preserveScroll: true,
      });
    },
  });

  return (
    <div>
      <table>
        <thead>
          <tr>
            <SortableHeader
              field="title"
              currentSort={flop.params.orderBy?.[0]}
              currentDirection={flop.getSortDirection('title')}
              onSort={flop.setSort}
            >
              Title
            </SortableHeader>
            <SortableHeader
              field="inserted_at"
              currentSort={flop.params.orderBy?.[0]}
              currentDirection={flop.getSortDirection('inserted_at')}
              onSort={flop.setSort}
            >
              Created
            </SortableHeader>
          </tr>
        </thead>
        <tbody>
          {posts.map(post => (
            <tr key={post.id}>
              <td>{post.title}</td>
              <td>{post.insertedAt}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <Pagination meta={meta} onPageChange={flop.setPage} />
    </div>
  );
}
```

### 4. Cursor-Based Pagination

For cursor-based pagination, use `CursorPagination` and cursor methods:

```tsx
import { useFlopParams, CursorPagination, flopToQueryParams } from '@/components/flop';

export default function PostsIndex({ posts, meta }: PostsIndexProps) {
  const flop = useFlopParams(meta, {
    onParamsChange: (params) => {
      router.visit(posts_path({ query: flopToQueryParams(params) }), {
        preserveState: true,
        preserveScroll: true,
      });
    },
  });

  return (
    <div>
      {/* ... table content ... */}

      <CursorPagination
        meta={meta}
        onNext={() => flop.goToNextCursor()}
        onPrevious={() => flop.goToPreviousCursor()}
      />
    </div>
  );
}
```

### 5. Filtering

Use the `FilterForm` component with render props for custom filter inputs:

```tsx
import { useFlopParams, FilterForm, flopToQueryParams } from '@/components/flop';

export default function PostsIndex({ posts, meta }: PostsIndexProps) {
  const flop = useFlopParams(meta, {
    onParamsChange: (params) => {
      router.visit(posts_path({ query: flopToQueryParams(params) }), {
        preserveState: true,
        preserveScroll: true,
      });
    },
  });

  return (
    <div>
      <FilterForm
        filterableFields={meta.filterableFields}
        filters={flop.params.filters ?? []}
        onFilterChange={(field, op, value) => flop.setFilter(field, op, value)}
        onFilterRemove={(field, op) => flop.removeFilter(field, op)}
        onClearFilters={() => flop.clearFilters()}
      >
        {({ fields, activeFilters, setFilter, removeFilter, clearFilters }) => (
          <>
            <input
              type="text"
              placeholder="Search title..."
              onChange={(e) => setFilter('title', 'ilike', `%${e.target.value}%`)}
            />

            <select onChange={(e) => setFilter('status', '==', e.target.value)}>
              <option value="">All</option>
              <option value="published">Published</option>
              <option value="draft">Draft</option>
            </select>

            {activeFilters.length > 0 && (
              <button onClick={clearFilters}>Clear all</button>
            )}
          </>
        )}
      </FilterForm>

      {/* ... rest of component ... */}
    </div>
  );
}
```

## useFlopParams Hook API

The `useFlopParams` hook provides:

### State

- `params` - Current Flop parameters (orderBy, orderDirections, filters, etc.)

### Pagination Methods

- `setPage(page)` - Go to specific page
- `nextPage()` - Go to next page
- `previousPage()` - Go to previous page
- `goToNextCursor()` - Go to next cursor (cursor-based)
- `goToPreviousCursor()` - Go to previous cursor (cursor-based)

### Sorting Methods

- `setSort(field, direction)` - Set sort field and direction
- `toggleSort(field)` - Toggle sort on a field (asc -> desc -> none)
- `getSortDirection(field)` - Get current sort direction for a field

### Filter Methods

- `setFilter(field, op, value)` - Add or update a filter
- `removeFilter(field, op)` - Remove a specific filter
- `clearFilters()` - Remove all filters
- `getFilterValue(field, op)` - Get value for a specific filter

## Helper Functions

### flopToQueryParams

Converts Flop params to URL query parameters:

```tsx
import { flopToQueryParams } from '@/components/flop';

const params = flopToQueryParams({
  page: 2,
  pageSize: 20,
  orderBy: ['title'],
  orderDirections: ['asc'],
  filters: [{ field: 'status', op: '==', value: 'published' }],
});
// => { page: '2', page_size: '20', order_by: 'title', order_directions: 'asc', ... }
```

## Styling

All components use CSS classes for styling. No styles are included - you style them yourself.

### CSS Classes

**Pagination:**
- `.flop-pagination` - Container
- `.flop-pagination-prev` / `.flop-pagination-next` - Navigation buttons
- `.flop-pagination-page` - Page buttons
- `.flop-pagination-page-active` - Active page button
- `.flop-pagination-ellipsis` - Ellipsis indicator

**CursorPagination:**
- `.flop-cursor-pagination` - Container
- `.flop-cursor-pagination-prev` / `.flop-cursor-pagination-next` - Navigation buttons

**SortableHeader:**
- `.flop-sortable-header` - Table header cell
- `.flop-sortable-header-active` - Active sort column
- `.flop-sortable-header-button` - Clickable button
- `.flop-sortable-header-label` - Text label
- `.flop-sortable-header-icon` - Sort direction icon

**FilterForm:**
- `.flop-filter-form` - Form container

## nb_stack Integration

If using `nb_stack`, install with the `--with-flop` flag:

```bash
mix igniter.install nb_stack --with-flop
```

This installs the complete frontend stack with Flop integration included.

## TypeScript Types

All components are fully typed. Types are generated by nb_ts when you run:

```bash
mix ts.gen
```

## License

MIT License - see LICENSE file for details.
