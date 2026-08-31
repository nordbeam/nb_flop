---
name: nb-flop
description: "Install, configure, upgrade, diagnose, and verify nb_flop tables, Flop pagination/filter metadata, React components, actions, exports, and saved views."
---

# NbFlop

Use this skill for `nb_flop` pagination, sorting, filtering, Table DSL resources, serializers, React table components, row/bulk actions, CSV exports, cursor pagination, or saved views in a Phoenix application.

## Discover the target release

- Inspect the target app's `mix.exs`, `mix.lock`, `assets/package.json`/lockfile, Ecto schemas and `@derive Flop.Schema` declarations, router, Inertia setup, generated serializers/components, and shadcn/ui availability. Read the selected README, installer task, Table DSL/compiler, router, and component source; docs and flags can differ by release.
- Preserve optional boundaries: `flop` is core, while `nb_serializer`, `nb_inertia`, Phoenix, CSV export support, NbTs, and frontend UI dependencies should be added only when requested and exposed by the target version.

## Install

- Prefer `mix igniter.install nb_flop`, optionally with task-supported `--table`, `--with-views`, `--with-exports`, and `--yes`. A table install may generate serializers, routes, a sample schema/table, and React components; review generated files and migrations before running them.
- Confirm the frontend package manager and required UI primitives before installing copied components. Do not assume `nb_stack` accepts a Flop flag; inspect the stack/inertia task that composes it.

## Implement and configure

- For Table DSL, define the target release's `NbFlop.Table` resource/repo/config/columns/filters/actions/bulk-actions/exports blocks, then call the generated table resource from the controller. Confirm column/filter/action option names from source before using examples.
- Add `use NbFlop.Router` and generated routes only when the router integration is available. Ensure Ecto schemas expose valid Flop filterable/sortable fields and that queries use the target Flop version's validation/run API.
- Feed the generated serialized metadata and row shape to the matching React components/hooks. Keep `nb_serializer`, `nb_inertia`, `nb_ts`, and route helpers coordinated but independently removable.
- Treat row and bulk action handlers as application-side effects: authorize, validate, and confirm destructive operations; configure CSV/saved views with their documented persistence and migration requirements.

## Upgrade or migrate

- Compare locked `nb_flop`/Flop versions, generated serializers/components/routes, React/TanStack dependencies, and Table DSL metadata before upgrading. Reconcile changes in filter operators, cursor/page metadata, row IDs, and serialized camelization.
- Migrate generated components as a unit when props or exports change. Preserve custom styling and handlers outside generated paths, and update shadcn/TanStack APIs deliberately.
- For saved views/exports, check database migrations, authorization, and CSV dependency changes separately from core table pagination.

## Diagnose and verify

- For invalid query params, inspect Flop schema derivation, field names/operators, query encoding, and page/cursor metadata. For empty or incorrect rows, inspect `Table.make`, repo/schema configuration, preloads, and serializer output.
- For frontend errors, compare generated component exports/types with installed React/TanStack versions and verify router/Inertia navigation preserves table state. For action failures, inspect route wiring, authorization, handler return values, and confirmation payloads.
- Verify with `mix deps.get`, `mix compile`, `mix test`, Flop query tests for sorting/filtering/page and cursor cases, generated TypeScript validation when NbTs is present, and a frontend build/component smoke test. Run migration/export/view checks only when enabled.
- If “latest” is requested, consult current HexDocs/GitHub for `nb_flop` and Flop, official TanStack documentation, and the relevant frontend package metadata; state the date checked and compare lockfiles.
