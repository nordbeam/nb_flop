# nb_flop Component Restructure Plan

## Goal

Consolidate nb_flop to use a single shadcn-based component set, backporting refined components from nb_pingcrm. Remove misleading "base-ui" and "radix-ui" naming.

## Current State

### nb_flop templates structure:
```
priv/components/
├── base-ui/
│   ├── flop/           # 10 files (incomplete)
│   └── table/          # 7 files (Table DSL)
└── radix-ui/
    └── flop/           # 16 files (more complete)
```

### nb_pingcrm components (source of truth):
```
assets/js/components/flop/   # 19 files (refined, production-ready)
```

### Problem:
- "base-ui" and "radix-ui" variants don't actually use those libraries
- Both expect shadcn components at `@/components/ui/*`
- Naming is misleading
- nb_pingcrm has more refined, battle-tested components

## Target State

### New structure:
```
priv/components/
└── flop/               # Single set of shadcn-based components
    ├── types.ts
    ├── tableTypes.ts   # Table DSL types
    ├── useFlopParams.ts
    ├── filterOperators.ts
    ├── filterUtils.ts  # DSL clause conversion
    ├── Pagination.tsx
    ├── CursorPagination.tsx
    ├── SortableHeader.tsx
    ├── SortableColumnHeader.tsx
    ├── DataTable.tsx
    ├── FilterForm.tsx
    ├── FilterBar.tsx
    ├── FilterChip.tsx
    ├── AddFilterButton.tsx
    ├── FilterValueInput.tsx
    ├── FilterValueSelect.tsx
    ├── FilterModeToggle.tsx
    ├── Table.tsx       # High-level Table DSL component
    └── index.ts
```

## Implementation Steps

### Phase 1: Restructure priv/components/

1. **Create new flop/ directory**
   - Create `priv/components/flop/`

2. **Copy components from nb_pingcrm**
   - Copy all 19 files from `nb_pingcrm/assets/js/components/flop/` to `nb_flop/priv/components/flop/`

3. **Remove old variant directories**
   - Delete `priv/components/base-ui/`
   - Delete `priv/components/radix-ui/`

### Phase 2: Update installer (nb_flop.install.ex)

1. **Remove UI library selection**
   - Remove `--ui` option from schema
   - Remove `Igniter.Util.IO.select` for UI library
   - Remove `ui_library` variable throughout

2. **Update copy_components/1**
   - Change source path from `Path.join([priv_dir, "components", source_dir, "flop"])` to `Path.join([priv_dir, "components", "flop"])`
   - Update component file list to include all 19 files:
     ```elixir
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
     ```

3. **Remove table components separation**
   - Table DSL components are now in the main flop/ directory
   - Remove `maybe_copy_table_components/3` function entirely
   - Remove `--table` flag handling for component copying (keep for routes/sample if desired)

4. **Update npm packages**
   - Always install `@tanstack/react-table`
   - Remove conditional Radix install (shadcn handles this)

5. **Add shadcn prerequisite check/notice**
   - Add message about required shadcn components

6. **Update success message**
   - Remove UI library references
   - Add note about shadcn components and styling customization

### Phase 3: Update documentation

1. **Update CLAUDE.md**
   - Remove UI library variant references
   - Document shadcn requirement
   - Update component list

2. **Update README.md** (if exists)
   - Remove UI library selection from usage
   - Add shadcn prerequisite section
   - Document customization approach

### Phase 4: Clean up nb_pingcrm

After backporting, nb_pingcrm continues to use its local copy. No changes needed there - the copy-to-codebase pattern means they're independent.

## Files to Modify

### Delete:
- `priv/components/base-ui/` (entire directory)
- `priv/components/radix-ui/` (entire directory)

### Create:
- `priv/components/flop/` (copy from nb_pingcrm)

### Modify:
- `lib/mix/tasks/nb_flop.install.ex`
- `CLAUDE.md`

## shadcn Components Required

Users must have these shadcn components installed:
- `button` - Used in FilterBar, FilterChip, AddFilterButton
- `badge` - Used in FilterChip
- `popover` - Used in FilterChip
- `dropdown-menu` - Used in AddFilterButton
- `command` - Used in AddFilterButton (searchable list)
- `input` - Used in FilterValueInput, AddFilterButton

Install command:
```bash
npx shadcn@latest add button badge popover dropdown-menu command input
```

## Installer Changes Detail

### Before (current):
```elixir
def igniter(igniter) do
  ui_library =
    igniter.args.options[:ui] ||
      Igniter.Util.IO.select(
        "Which UI library would you like to use?",
        [:base, :radix],
        display: fn
          :base -> "Base UI (unstyled primitives from MUI team)"
          :radix -> "Radix UI (accessibility-first primitives)"
        end
      )
  ...
end
```

### After (simplified):
```elixir
def igniter(igniter) do
  with_table = igniter.args.options[:table]
  ...

  igniter
  |> print_welcome(with_table)
  |> add_dependencies(with_exports)
  |> generate_serializers()
  |> copy_components()  # No ui_library arg
  |> maybe_add_routes(with_table)
  |> maybe_generate_sample_table(with_table)
  |> maybe_setup_views(with_views)
  |> install_npm_packages()  # No ui_library arg
  |> print_success(with_table)
end
```

### copy_components/1 changes:
```elixir
defp copy_components(igniter) do
  priv_dir = :code.priv_dir(:nb_flop)
  source_path = Path.join([priv_dir, "components", "flop"])
  dest_path = "assets/js/components/flop"

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
```

## Testing Plan

1. Create fresh Phoenix app with nb_inertia
2. Install shadcn components:
   ```bash
   cd assets
   npx shadcn@latest init
   npx shadcn@latest add button badge popover dropdown-menu command input
   ```
3. Run `mix nb_flop.install`
4. Verify:
   - All 19 components copied to `assets/js/components/flop/`
   - Serializers generated
   - npm packages installed (@tanstack/react-table)
5. Build frontend - verify no import errors
6. Test basic table with pagination/sorting/filtering

## Rollback Plan

If issues arise:
1. Git revert the changes to nb_flop
2. Keep nb_pingcrm unchanged (it's independent)

## Success Criteria

- [ ] Single component set in `priv/components/flop/`
- [ ] Installer works without UI library selection
- [ ] All 19 components from nb_pingcrm backported
- [ ] Documentation updated
- [ ] Fresh install works in test app
- [ ] No breaking changes for existing nb_flop users (they own their code)

## Notes

- This restructure focuses on the component distribution, not the Table DSL backend
- The existing PLAN.md covers feature expansion (Table DSL, actions, exports, etc.)
- This is a prerequisite cleanup before those features
- nb_pingcrm serves as the proving ground for component refinement
