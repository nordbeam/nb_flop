# NbFlop Usage Rules

`nb_flop` adds typed Flop pagination, sorting, filtering, and table-resource
support to Phoenix applications. It also provides serializers for Flop
metadata and optional React components for tables, actions, exports, and saved
views.

## Composition

- Keep `flop` as the core dependency. Add `nb_serializer`, `nb_inertia`,
  Phoenix, CSV, and frontend dependencies only for the integrations the app
  uses.
- Use `NbFlop.Table` for declarative table resources and keep the schema/repo
  configuration next to the table's columns, filters, and actions.
- Use `NbFlop.Router` and generated routes only when the app's router exposes
  the integration; do not assume route generation is enabled by the base
  package.

## Installation

Use the package installer and select optional features deliberately:

```bash
mix igniter.install nb_flop
mix igniter.install nb_flop --table
mix igniter.install nb_flop --with-views --with-exports
```

Review generated serializers, React components, routes, and migrations before
committing them. Saved views require the generated migration and application
authorization. Destructive row and bulk actions must be authorized and
confirmed by the application.

## Verification

When diagnosing a table, check Flop schema derivation, filter operators,
encoded query parameters, page/cursor metadata, serializer output, and the
installed React/TanStack versions as one contract. Run `mix compile` and
`mix test`; run a frontend build when components are installed.
