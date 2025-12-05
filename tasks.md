# Phase 1: Core Infrastructure

## nb_flop-c45.1 - Table behaviour and struct
type: task
priority: P0
parent: nb_flop-c45
description: |
  Create the core Table behaviour and struct that all table modules will implement.

  ## Implementation

  1. Define `NbFlop.Table` behaviour with callbacks:
     - `columns/0` -> list of column structs
     - `filters/0` -> list of filter structs
     - `actions/0` -> list of action structs
     - `resource/0` -> Ecto schema or queryable
     - `config/0` -> table configuration

  2. Create `NbFlop.Table.Config` struct with name, default_sort, default_per_page, per_page_options, sticky_header, searchable

  ## TDD Acceptance Criteria

  - [ ] NbFlop.Table behaviour defined with all callbacks
  - [ ] NbFlop.Table.Config struct with defaults
  - [ ] Test: behaviour callbacks are enforced
  - [ ] Test: config struct has sensible defaults

---

## nb_flop-c45.2 - Table DSL macros
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Implement the `use NbFlop.Table` macro that provides the DSL for defining tables.

  ## Implementation

  1. __using__/1 macro that imports DSL, registers attributes, sets up @before_compile
  2. DSL macros: resource/1, config/1, columns/1, filters/1, actions/1
  3. __before_compile__/1 generates behaviour callbacks and make/2

  ## TDD Acceptance Criteria

  - [ ] use NbFlop.Table provides DSL
  - [ ] Module attributes accumulate definitions
  - [ ] Before compile generates behaviour implementations
  - [ ] Test: simple table module compiles
  - [ ] Test: missing required fields raises helpful error
  - [ ] Test: make/2 function is generated

---

## nb_flop-c45.3 - Column structs and types
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Implement column struct and all column types.

  ## Column Types

  1. NbFlop.Column base struct: key, label, type, sortable, searchable, toggleable, visible, stickable, alignment, wrap, truncate, header_class, cell_class, clickable (fn), map_as (fn), meta

  2. Type modules: Text, Badge (colors), Numeric (prefix/suffix/decimals), Date (format), DateTime (format), Boolean, Image (width/height/rounded), Action

  3. DSL macros: text_column/2, badge_column/2, etc.

  ## TDD Acceptance Criteria

  - [ ] Base Column struct with all common fields
  - [ ] Each column type has constructor with defaults
  - [ ] DSL macros create correct column structs
  - [ ] Test: text_column with options
  - [ ] Test: badge_column with colors map
  - [ ] Test: numeric_column with formatting options
  - [ ] Test: date_column with format string

---

## nb_flop-c45.4 - Filter structs and types
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Implement filter struct and all filter types.

  ## Filter Types

  1. NbFlop.Filter base struct: field, label, type, clauses, default_clause, options, nullable, min, max

  2. Types: Text (contains/starts_with/equals), Numeric (equals/gt/gte/lt/lte/between), Set (options), Date, Boolean

  3. DSL macros: text_filter/2, numeric_filter/2, set_filter/2, etc.

  ## TDD Acceptance Criteria

  - [ ] Base Filter struct with all fields
  - [ ] Each filter type has constructor with defaults
  - [ ] Clauses are validated per filter type
  - [ ] Test: text_filter with custom clauses
  - [ ] Test: set_filter with options
  - [ ] Test: date_filter with min/max dates

---

## nb_flop-c45.5 - Table.make/2 core implementation
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.2,nb_flop-c45.3,nb_flop-c45.4
description: |
  Implement the core Table.make/2 function that executes queries and builds the resource.

  ## Implementation

  1. Parse URL params (respect table name prefix)
  2. Convert to Flop params
  3. Call Flop.validate_and_run/3
  4. Transform rows through columns (map_as functions)
  5. Build state map from current params
  6. Return resource map: {data, meta, state, columns, filters, name, per_page_options}

  ## TDD Acceptance Criteria

  - [ ] make/2 returns correct resource structure
  - [ ] Flop query is executed with params
  - [ ] Rows are transformed via column.map_as
  - [ ] State reflects current params
  - [ ] Test: basic make/2 returns all fields
  - [ ] Test: sorting params are applied
  - [ ] Test: filter params are applied
  - [ ] Test: pagination params are applied
  - [ ] Test: map_as transforms values

---

# Phase 2: Serialization

## nb_flop-c45.6 - Column serializer
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.3
description: |
  Implement serialization of column definitions for frontend consumption.

  ## Implementation

  NbFlop.Serializers.ColumnSerializer: key, type, label, sortable, searchable, toggleable, visible, alignment, stickable. Type-specific: colors, prefix, suffix, decimals, format, width, height, rounded.

  Function callbacks (map_as, clickable) are NOT serialized.

  ## TDD Acceptance Criteria

  - [ ] Column struct serializes to map
  - [ ] Type-specific options included
  - [ ] Function callbacks are NOT serialized
  - [ ] Test: text column serialization
  - [ ] Test: badge column includes colors
  - [ ] Test: numeric column includes formatting

---

## nb_flop-c45.7 - Filter serializer
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.4
description: |
  Implement serialization of filter definitions for frontend.

  ## Implementation

  NbFlop.Serializers.FilterSerializer: field, type, label, clauses (list of strings), options (for set filters), nullable, validation constraints.

  ## TDD Acceptance Criteria

  - [ ] Filter struct serializes to map
  - [ ] Set filter includes options
  - [ ] Clauses are string list
  - [ ] Test: text filter serialization
  - [ ] Test: set filter with options

---

## nb_flop-c45.8 - Table resource serializer
type: task
priority: P0
parent: nb_flop-c45
deps: nb_flop-c45.5,nb_flop-c45.6,nb_flop-c45.7
description: |
  Implement complete table resource serialization combining all parts.

  ## Implementation

  NbFlop.Serializers.TableSerializer.serialize/2:
  1. Serialize data rows (already transformed)
  2. Serialize meta (from Flop.Meta)
  3. Serialize state (current params)
  4. Serialize columns (via ColumnSerializer)
  5. Serialize filters (via FilterSerializer)
  6. Add config (name, per_page_options, sticky_header)

  ## TDD Acceptance Criteria

  - [ ] Full resource map generated
  - [ ] All nested structures serialized
  - [ ] JSON-encodable output
  - [ ] Test: complete serialization roundtrip
  - [ ] Test: output matches expected frontend structure

---

# Phase 3: Actions System

## nb_flop-c45.9 - Action struct
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Implement the Action struct for row actions.

  ## Implementation

  NbFlop.Action: name, label, icon, variant, url (fn), handle (fn), disabled (fn), hidden (fn), confirmation, frontend, authorize, success_message, error_message

  NbFlop.Confirmation: title, message, confirm_button, cancel_button, icon, variant

  DSL: action/2 macro

  ## TDD Acceptance Criteria

  - [ ] Action struct with all fields
  - [ ] Confirmation struct
  - [ ] DSL: action/2 macro
  - [ ] Test: link action with url fn
  - [ ] Test: handler action with handle fn
  - [ ] Test: action with confirmation
  - [ ] Test: disabled/hidden callbacks

---

## nb_flop-c45.10 - Per-row action evaluation
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.9,nb_flop-c45.5
description: |
  Implement per-row evaluation of action states (url, disabled, hidden).

  ## Implementation

  NbFlop.Action.evaluate_for_row/3 computes url, disabled, hidden for each row.

  Integration with Table.make/2: For each row, evaluate all actions and add _actions map to row data.

  ## TDD Acceptance Criteria

  - [ ] evaluate_for_row/3 computes all states
  - [ ] Rows include _actions map
  - [ ] Different rows can have different action states
  - [ ] Test: disabled fn returns true for some rows
  - [ ] Test: hidden fn returns true for some rows
  - [ ] Test: url fn generates correct URL per row

---

## nb_flop-c45.11 - Token generation and verification
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.2
description: |
  Implement signed token system for action authentication.

  ## Implementation

  NbFlop.Token with sign/2 and verify/2 using Phoenix.Token. Encodes table module, context, issued_at. Verifies module is valid table.

  ## TDD Acceptance Criteria

  - [ ] sign/2 generates valid Phoenix token
  - [ ] verify/1 extracts table module
  - [ ] Invalid tokens return error
  - [ ] Expired tokens return error
  - [ ] Non-table modules return error
  - [ ] Test: roundtrip sign -> verify
  - [ ] Test: tampered token fails
  - [ ] Test: expired token fails

---

## nb_flop-c45.12 - Action controller
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.10,nb_flop-c45.11
description: |
  Implement the controller endpoint for executing actions.

  ## Implementation

  NbFlop.ActionController.execute/2: verify token, find action, authorize, load row, check not disabled, execute handler.

  Router macro: nb_flop_routes/1 adds POST /nb-flop/action route.

  ## TDD Acceptance Criteria

  - [ ] POST /nb-flop/action executes action handler
  - [ ] Token verification required
  - [ ] Action authorization checked
  - [ ] Disabled actions rejected
  - [ ] Success/error responses correct format
  - [ ] Test: valid action execution
  - [ ] Test: invalid token rejected
  - [ ] Test: disabled action rejected

---

## nb_flop-c45.13 - Action serializer
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.9
description: |
  Serialize action definitions for frontend.

  ## Implementation

  NbFlop.Serializers.ActionSerializer: name, label, icon, variant, confirmation (nested), frontend. url/disabled/hidden/handle NOT serialized.

  ## TDD Acceptance Criteria

  - [ ] Static action fields serialized
  - [ ] Confirmation struct serialized
  - [ ] Callbacks not serialized
  - [ ] Test: action with confirmation
  - [ ] Test: frontend action flag

---

# Phase 4: Bulk Actions

## nb_flop-c45.14 - Bulk action struct
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.9
description: |
  Implement bulk action struct and DSL.

  ## Implementation

  NbFlop.BulkAction: name, label, icon, variant, handle (fn(rows)), confirmation, authorize, chunk_size, before, after

  DSL: bulk_actions do ... end, bulk_action/2 macro

  ## TDD Acceptance Criteria

  - [ ] BulkAction struct with all fields
  - [ ] DSL macros work
  - [ ] Test: bulk action with handler
  - [ ] Test: bulk action with confirmation
  - [ ] Test: chunk_size option

---

## nb_flop-c45.15 - Row selectability
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.14,nb_flop-c45.5
description: |
  Implement per-row selectability for bulk actions.

  ## Implementation

  Optional selectable?/2 callback in Table (default true). In Table.make/2, add _selectable to each row.

  ## TDD Acceptance Criteria

  - [ ] Default selectable?/2 returns true
  - [ ] Custom selectable?/2 can exclude rows
  - [ ] _selectable added to row data
  - [ ] Test: all rows selectable by default
  - [ ] Test: some rows not selectable

---

## nb_flop-c45.16 - Bulk action controller
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.14,nb_flop-c45.15,nb_flop-c45.11
description: |
  Implement controller for bulk action execution.

  ## Implementation

  Selection modes: explicit (IDs), all (filters), all_except. Chunk processing, before/after callbacks.

  POST /nb-flop/bulk-action endpoint.

  ## TDD Acceptance Criteria

  - [ ] Explicit mode loads specific IDs
  - [ ] All mode uses filters to query
  - [ ] All_except mode excludes IDs
  - [ ] Chunk processing works
  - [ ] Before/after callbacks called
  - [ ] Test: explicit selection
  - [ ] Test: select all

---

# Phase 5: Export System

## nb_flop-c45.17 - Export struct and DSL
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Implement export definition struct and DSL.

  ## Implementation

  NbFlop.Export: name, label, format (:csv/:excel), columns, format_column, filename, authorize, queue

  DSL: exports do ... end, export/2 macro

  ## TDD Acceptance Criteria

  - [ ] Export struct with all fields
  - [ ] DSL macros work
  - [ ] Test: basic export definition
  - [ ] Test: export with column subset

---

## nb_flop-c45.18 - CSV exporter
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.17
description: |
  Implement CSV export generation.

  ## Implementation

  NbFlop.Exporters.CSV.generate/3: headers from column labels, values formatted per format_column.

  ## TDD Acceptance Criteria

  - [ ] Generates valid CSV
  - [ ] Headers from column labels
  - [ ] Values formatted correctly
  - [ ] Test: basic CSV generation
  - [ ] Test: with format_column functions

---

## nb_flop-c45.19 - Export controller
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.17,nb_flop-c45.18,nb_flop-c45.11
description: |
  Implement export download endpoint.

  ## Implementation

  GET /nb-flop/export: verify token, authorize, load rows (respecting filters/selection), generate file, return download.

  ## TDD Acceptance Criteria

  - [ ] GET /nb-flop/export returns file
  - [ ] Respects current filters
  - [ ] Respects selected rows
  - [ ] Correct content-type and filename
  - [ ] Test: CSV download

---

# Phase 6: Views (Saved States)

## nb_flop-c45.20 - Views database schema
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Create database schema and migration for saved views.

  ## Implementation

  Schema: name, table_name, user_id, state (map), is_default, shared, attributes. Migration generator task.

  ## TDD Acceptance Criteria

  - [ ] Ecto schema defined
  - [ ] Migration creates table
  - [ ] Indexes on table_name, user_id
  - [ ] Test: schema CRUD operations

---

## nb_flop-c45.21 - Views configuration
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.20
description: |
  Implement views configuration in Table DSL.

  ## Implementation

  NbFlop.Views: enabled, scope_user, user_resolver, attributes, scope_table_name

  DSL: views do ... end

  ## TDD Acceptance Criteria

  - [ ] Views struct with config
  - [ ] DSL macros work
  - [ ] User resolver called correctly
  - [ ] Test: views enabled
  - [ ] Test: user scoping

---

## nb_flop-c45.22 - Views controller
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.20,nb_flop-c45.21,nb_flop-c45.11
description: |
  Implement CRUD controller for views.

  ## Endpoints

  GET /nb-flop/views, POST /nb-flop/views, PUT /nb-flop/views/:id, DELETE /nb-flop/views/:id, POST /nb-flop/views/:id/default

  ## TDD Acceptance Criteria

  - [ ] List views filtered by table/user
  - [ ] Create saves current state
  - [ ] Update modifies existing
  - [ ] Delete removes view
  - [ ] Default flag updated
  - [ ] Test: full CRUD cycle

---

# Phase 7: Frontend Components

## nb_flop-c45.23 - useTable hook
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.8
description: |
  Implement React hook for table state management.

  ## Implementation

  useTable<T>(resource): state, columns, visibleColumns, sort/filter/search/pagination methods, toggleColumn, views management. URL sync via Inertia.

  ## TDD Acceptance Criteria

  - [ ] Hook returns all state
  - [ ] Sort changes update state + URL
  - [ ] Filter changes update state + URL
  - [ ] Column toggle updates visibility
  - [ ] Test: sort toggle cycle
  - [ ] Test: filter add/remove

---

## nb_flop-c45.24 - useActions hook
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.13
description: |
  Implement React hook for selection and action execution.

  ## Implementation

  useActions<T>(resource): selection state (explicit/all/all_except modes), isSelected, toggleItem, selectAll, clearSelection, executeAction, executeBulkAction.

  ## TDD Acceptance Criteria

  - [ ] Selection state managed
  - [ ] Explicit mode tracks IDs
  - [ ] All mode inverts tracking
  - [ ] executeAction POSTs to endpoint
  - [ ] Test: selection toggle
  - [ ] Test: select all

---

## nb_flop-c45.25 - Table component
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.23,nb_flop-c45.24
description: |
  Implement main Table React component.

  ## Implementation

  Table<T>({ resource, slots }): TableTopbar, FilterBar, BulkActionBar, TableContent/EmptyState, TableFooter

  ## TDD Acceptance Criteria

  - [ ] Renders table structure
  - [ ] Topbar with search/filters/exports
  - [ ] Bulk action bar when selected
  - [ ] Empty state when no data
  - [ ] Test: renders with data
  - [ ] Test: renders empty state

---

## nb_flop-c45.26 - Cell renderer components
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.25
description: |
  Implement cell renderers for each column type.

  ## Components

  TextCell, BadgeCell, NumericCell, DateCell, BooleanCell, ImageCell, ActionCell

  ## TDD Acceptance Criteria

  - [ ] Each cell type renders correctly
  - [ ] BadgeCell applies colors
  - [ ] NumericCell formats with prefix/suffix
  - [ ] ActionCell shows dropdown
  - [ ] Test: each cell type renders

---

## nb_flop-c45.27 - ConfirmationDialog component
type: task
priority: P1
parent: nb_flop-c45
deps: nb_flop-c45.25
description: |
  Implement confirmation dialog for destructive actions.

  ## Implementation

  ConfirmationDialog: open, title, message, confirmLabel, cancelLabel, variant, onConfirm, onCancel

  ## TDD Acceptance Criteria

  - [ ] Dialog renders with content
  - [ ] Confirm button calls onConfirm
  - [ ] Cancel button calls onCancel
  - [ ] Variant styles danger actions
  - [ ] Test: open/close

---

# Phase 8: Integration

## nb_flop-c45.28 - Empty state configuration
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.1
description: |
  Implement empty state struct and DSL.

  ## Implementation

  NbFlop.EmptyState: title, message, icon, action (label, url, variant)

  DSL: empty_state do ... end

  ## TDD Acceptance Criteria

  - [ ] EmptyState struct
  - [ ] DSL macros work
  - [ ] Serializes correctly
  - [ ] Test: empty state with action

---

## nb_flop-c45.29 - Multiple tables support
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.5
description: |
  Support multiple tables on same page with URL namespacing.

  ## Implementation

  as/2 sets table name. Param parsing respects prefix: default ?sort=name, named ?orders[sort]=date

  ## TDD Acceptance Criteria

  - [ ] as/2 sets table name
  - [ ] Params parsed with prefix
  - [ ] Multiple tables don't conflict
  - [ ] Test: two tables on page

---

## nb_flop-c45.30 - Installer updates
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.25,nb_flop-c45.12
description: |
  Update Igniter installer for new Table DSL.

  ## Updates

  Copy new frontend components, generate example Table module, add routes, migration for views (optional).

  ## TDD Acceptance Criteria

  - [ ] Installer copies all components
  - [ ] Routes added correctly
  - [ ] Example table compiles
  - [ ] Migration generated if --with-views

---

## nb_flop-c45.31 - Documentation and examples
type: task
priority: P2
parent: nb_flop-c45
deps: nb_flop-c45.30
description: |
  Comprehensive documentation and examples.

  ## Docs

  README, Table DSL reference, Column types, Actions, Bulk actions, Exports, Views, Frontend customization.

  ## Acceptance Criteria

  - [ ] README updated
  - [ ] All features documented
  - [ ] Examples compile and work
