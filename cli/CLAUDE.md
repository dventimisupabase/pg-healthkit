# CLI Island — Go CLI Plugin for Probe Collection

## What This Is

A Go CLI tool (intended as a Supabase CLI plugin) that executes SQL probes against PostgreSQL databases, normalizes the results into canonical payloads, and uploads evidence to the Arena.

## Architecture

```
CLI
├── Probe Runner      — loads registry, selects by profile, executes SQL
├── Normalizer        — converts raw tabular output to canonical payloads
├── Uploader          — sends evidence to Arena API
└── Probes (SQL)      — SQL files executed against the target database
```

## Key Contracts (read these first)

- `../contracts/probe_registry.yaml` — defines what each probe collects and its payload shape
- `../contracts/normalizer_spec.md` — rules for type coercion, summary derivation, interval handling
- `../contracts/normalizer_interface_contract.md` — raw input shape → canonical output shape
- `../contracts/cli_contract.md` — CLI commands, flags, JSON request/response payloads

## Design Docs

- `../docs/04_probe_system.md` — probe model, classification, 24 probes, mapping matrices
- `../docs/08_probe_catalog.md` — human-readable probe catalog with interpretation notes

## What the CLI Does

1. Load probe registry
2. Select probes by profile (default, performance, reliability, cost_capacity, supabase_default)
3. Check prerequisites (extensions, capabilities)
4. Execute SQL probes against the target database
5. Normalize raw output into canonical payloads
6. Validate payloads against registry contracts
7. Upload evidence to the Arena (or export as JSON for local workflows)

## What the CLI Does NOT Do

- Evaluate rules or produce findings
- Compute scores
- Generate reports
- Store assessment state (that's the Arena's job)

## Implementation Language

Go — to align with the existing Supabase CLI.

## Probe SQL Files

SQL files live in `probes/`. Naming convention: `NN_probe_name.sql` where NN is a numeric prefix for ordering.

Probes should be executable standalone via `psql` for manual use.

## Testing

Use fixtures in `testdata/`:
- `testdata/raw/` — raw SQL output examples
- `testdata/canonical/` — expected normalized payloads
- `testdata/skipped/` — skipped probe examples
- `testdata/failed/` — failed probe examples

Each probe needs tests for: success with rows, success with zero rows, skipped, and failed.

## Build Order

1. Contract loader (parse `probe_registry.yaml`)
2. One probe runner (execute SQL, capture raw output)
3. One normalizer (convert to canonical payload)
4. Validate against registry
5. Generalize after the vertical slice works

Start with `long_running_transactions` as the first probe. For Supabase, add `rls_policy_column_indexing` early.
