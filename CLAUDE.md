# CLAUDE.md - nb_flop

Developer guidance for Claude Code when working with the nb_flop package.

## Package Overview

**nb_flop** provides Flop integration for the nb ecosystem. It generates serializers and copies React components into user codebases for pagination, sorting, and filtering.

**Repository**: https://github.com/nordbeam/nb_flop

## Architecture

### Design Philosophy

NbFlop follows the "copy-to-codebase" pattern (like shadcn/ui):

1. **Serializers are generated** - Written to user's `lib/app_web/serializers/` directory
2. **Components are copied** - Placed in user's `assets/js/components/flop/`
3. **Users own the code** - Full customization without upstream dependencies

This approach allows users to:
- Modify serializers for their specific needs
- Style components however they want
- Extend functionality without forking

### Package Structure

```
nb_flop/
├── lib/
│   ├── nb_flop.ex                    # Main module with docs
│   └── mix/
│       └── tasks/
│           └── nb_flop.install.ex    # Igniter-based installer
├── priv/
│   └── components/
│       └── flop/                     # React components (shadcn/ui based)
│           ├── types.ts              # Core Flop TypeScript types
│           ├── tableTypes.ts         # Table DSL resource types
│           ├── useFlopParams.ts      # State management hook
│           ├── filterOperators.ts    # Filter operator utilities
│           ├── filterUtils.ts        # DSL clause conversion utilities
│           ├── Pagination.tsx        # Page-based pagination
│           ├── CursorPagination.tsx  # Cursor-based pagination
│           ├── SortableHeader.tsx    # Standalone sortable header
│           ├── SortableColumnHeader.tsx  # TanStack Table sortable header
│           ├── DataTable.tsx         # TanStack Table wrapper
│           ├── FilterForm.tsx        # Render prop filter container
│           ├── FilterBar.tsx         # Linear-style filter bar
│           ├── FilterChip.tsx        # Individual filter chip
│           ├── AddFilterButton.tsx   # Add filter dropdown
│           ├── FilterValueInput.tsx  # Text/number filter input
│           ├── FilterValueSelect.tsx # Select filter input
│           ├── FilterModeToggle.tsx  # AND/OR filter mode toggle
│           ├── Table.tsx             # High-level Table DSL component
│           └── index.ts              # Re-exports
├── mix.exs
├── README.md
└── CLAUDE.md
```

## Key Files

### lib/nb_flop.ex

Main module with version constant and documentation. No runtime code - this package is purely an installer.

### lib/mix/tasks/nb_flop.install.ex

The Igniter-based installer that:

1. **Adds flop dependency** - `{:flop, "~> 0.26"}`
2. **Generates serializers** - Four serializers to user's codebase
3. **Copies components** - 19 React files to assets (shadcn/ui based)
4. **Installs npm packages** - `@tanstack/react-table`

**Key Functions:**

```elixir
# Generating serializers
Igniter.create_new_file(igniter, module_to_path(module), content, on_exists: :skip)

# Copying components from priv
priv_dir = :code.priv_dir(:nb_flop)
source_path = Path.join([priv_dir, "components", "flop"])
```

### priv/components/flop/

Contains React components that use shadcn/ui. Components import from `@/components/ui/*` paths.

**Required shadcn components:**
```bash
npx shadcn@latest add button badge popover dropdown-menu command input
```

Components are styled with Tailwind CSS and can be customized after copying to user's codebase.

## Generated Serializers

### FlopFilterSerializer

Serializes individual `Flop.Filter` structs:

```elixir
schema do
  field :field, :string
  field :op, :string, compute: :compute_op
  field :value, :any
end
```

### FlopParamsSerializer

Serializes the `Flop` struct with all pagination/sorting parameters:

```elixir
schema do
  field :order_by, list: :string, compute: :compute_order_by, optional: true
  field :order_directions, list: :string, compute: :compute_order_directions, optional: true
  field :page, :number, optional: true, nullable: true
  field :page_size, :number, optional: true, nullable: true
  # ... cursor fields, offset fields
  has_many :filters, FlopFilterSerializer
end
```

### FlopMetaSerializer

Serializes `Flop.Meta` with schema introspection:

```elixir
schema do
  field :current_page, :number, nullable: true
  field :total_pages, :number, nullable: true
  # ... other meta fields
  has_one :flop, FlopParamsSerializer
  field :filterable_fields, list: FilterableFieldSerializer, compute: :compute_filterable_fields, optional: true
  field :sortable_fields, list: :string, compute: :compute_sortable_fields, optional: true
end
```

The `schema` option in serializer opts enables introspection:

```elixir
render_inertia(conn, :posts_index,
  meta: {FlopMetaSerializer, meta, schema: Post}
)
```

### FilterableFieldSerializer

Serializes field metadata for frontend filter UI:

```elixir
schema do
  field :field, :string
  field :label, :string
  field :type, enum: ["string", "number", "boolean", "date", "datetime", "array", "enum"]
  field :operators, list: :string
end
```

## React Components

### useFlopParams.ts

UI-agnostic hook for Flop state management:

```typescript
export function useFlopParams(meta: FlopMeta, options: UseFlopParamsOptions): UseFlopParamsReturn {
  const [params, setParams] = useState<FlopParams>(() => meta.flop || {});

  // Pagination
  const setPage = (page: number) => { ... };
  const nextPage = () => { ... };
  const previousPage = () => { ... };
  const goToNextCursor = () => { ... };
  const goToPreviousCursor = () => { ... };

  // Sorting
  const setSort = (field: string, direction: SortDirection) => { ... };
  const toggleSort = (field: string) => { ... };
  const getSortDirection = (field: string) => { ... };

  // Filtering
  const setFilter = (field: string, op: string, value: unknown) => { ... };
  const removeFilter = (field: string, op: string) => { ... };
  const clearFilters = () => { ... };

  return { params, setPage, nextPage, ... };
}
```

### flopToQueryParams

Converts Flop params to URL-friendly query params:

```typescript
export function flopToQueryParams(params: FlopParams): Record<string, string> {
  // Converts camelCase to snake_case
  // Handles arrays and nested filter objects
  // Returns flat query parameter object
}
```

### Pagination.tsx

Page-based pagination with ellipsis:

```tsx
<nav className="flop-pagination">
  <button className="flop-pagination-prev">Previous</button>
  <button className="flop-pagination-page">1</button>
  <span className="flop-pagination-ellipsis">...</span>
  <button className="flop-pagination-page flop-pagination-page-active">5</button>
  <button className="flop-pagination-next">Next</button>
</nav>
```

### CursorPagination.tsx

Cursor-based pagination (no page numbers):

```tsx
<nav className="flop-cursor-pagination">
  <button className="flop-cursor-pagination-prev">Previous</button>
  <button className="flop-cursor-pagination-next">Next</button>
</nav>
```

### SortableHeader.tsx

Table header with sort toggle:

```tsx
<th className="flop-sortable-header flop-sortable-header-active">
  <button className="flop-sortable-header-button" aria-sort="ascending">
    <span className="flop-sortable-header-label">Title</span>
    <span className="flop-sortable-header-icon">↑</span>
  </button>
</th>
```

### FilterForm.tsx

Render prop pattern for custom filters:

```tsx
<FilterForm
  filterableFields={meta.filterableFields}
  filters={params.filters}
  onFilterChange={setFilter}
  onFilterRemove={removeFilter}
  onClearFilters={clearFilters}
>
  {({ fields, activeFilters, setFilter, removeFilter, clearFilters }) => (
    // User builds their own filter UI
  )}
</FilterForm>
```

## Development Commands

```bash
cd nb_flop

# Install dependencies
mix deps.get

# Run tests
mix test

# Format code
mix format

# Generate documentation
mix docs
```

## Testing

### Manual Testing

1. Create a test Phoenix app with nb_inertia
2. Install shadcn components:
   ```bash
   cd assets && npx shadcn@latest add button badge popover dropdown-menu command input
   ```
3. Add nb_flop as a path dependency:
   ```elixir
   {:nb_flop, path: "../nb_flop"}
   ```
4. Run the installer:
   ```bash
   mix nb_flop.install
   ```
5. Verify:
   - Serializers created in `lib/app_web/serializers/`
   - All 19 components copied to `assets/js/components/flop/`
   - Flop dependency added to mix.exs
   - `@tanstack/react-table` installed

### Integration Testing

Test the full flow:

1. Add `@derive Flop.Schema` to an Ecto schema
2. Use `Flop.validate_and_run/3` in controller
3. Serialize with `FlopMetaSerializer`
4. Use components in React

## Common Issues

### Issue: Components not found after install

**Cause**: Assets directory doesn't exist or has different structure

**Fix**: Ensure `assets/js/components/` exists before running installer

### Issue: Serializer module conflicts

**Cause**: Serializers already exist with same name

**Fix**: Installer uses `on_exists: :skip` - existing files are preserved

### Issue: npm packages not installed

**Cause**: Package manager detection may fail

**Fix**: Manually run the install command shown in success message

## Integration with Other nb Packages

### nb_serializer

Generated serializers use nb_serializer DSL:

```elixir
use NbSerializer.Serializer

schema do
  field :name, :string
  has_many :items, ItemSerializer
end
```

### nb_inertia

Use serializers with render_inertia:

```elixir
render_inertia(conn, :page_name,
  meta: {FlopMetaSerializer, meta, schema: Post}
)
```

### nb_ts

Types are generated from serializers:

```bash
mix ts.gen
```

Produces TypeScript interfaces for `FlopMeta`, `FlopParams`, etc.

### nb_routes

Components work with nb_routes for navigation:

```typescript
router.visit(posts_path({ query: flopToQueryParams(params) }));
```

### nb_stack

Install as part of the full stack:

```bash
mix igniter.install nb_stack --with-flop
```

## Future Enhancements

Potential improvements:

1. **Vue components** - Add Vue 3 version of components
2. **Svelte components** - Add Svelte version
3. **Filter presets** - Common filter patterns (date range, search, etc.)
4. **Infinite scroll** - Component for infinite scroll pagination
5. **Table DSL enhancements** - More column types, export formats

## Design Decisions

### Why copy components instead of npm package?

1. **Full customization** - Users can modify anything
2. **No version conflicts** - Components don't depend on external versions
3. **Style freedom** - No CSS framework lock-in
4. **Smaller bundle** - Only used components are included

### Why separate serializers?

1. **Modularity** - Use only what you need
2. **Type safety** - nb_ts generates types for each
3. **Customization** - Easy to extend individual serializers

### Why render props for FilterForm?

1. **Flexibility** - Users build their own filter UI
2. **No assumptions** - Works with any form library
3. **Full control** - Style and layout as needed

## Related Resources

- **Flop docs**: https://hexdocs.pm/flop
- **nb_serializer**: See nb_serializer/CLAUDE.md
- **nb_inertia**: See nb_inertia/CLAUDE.md
- **nb_ts**: See nb_ts/CLAUDE.md
