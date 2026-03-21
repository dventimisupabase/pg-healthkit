# SQL Probe Pack

## Overview

This directory contains the SQL probes for pg-healthkit. These are standalone queries that can be run directly via `psql` without any CLI tooling. This is the Phase 1 deliverable: any SA, DBA, or support engineer can use these files to collect structured health evidence from a PostgreSQL database.

## Directory Structure

```
probes/
  00–09  Instance and platform
  10–19  Activity and connections
  20–29  Query analysis
  30–39  Tables, indexes, storage
  40–49  Replication and WAL
  50–59  Security and hygiene
  60–69  Supabase-specific
```

All probes live in a flat directory. The numbering convention groups probes by domain.

## Probe Numbering Convention

| Range  | Domain                      | Category   |
|--------|-----------------------------|------------|
| 00–09  | Instance and platform       | Baseline   |
| 10–19  | Activity and connections    | Baseline   |
| 20–29  | Query analysis              | Baseline (requires pg_stat_statements) |
| 30–39  | Tables, indexes, storage    | Baseline   |
| 40–49  | Replication and WAL         | Contextual |
| 50–59  | Security and hygiene        | Baseline   |
| 60–69  | Supabase-specific           | Contextual |

## Running Probes with psql

### Single probe

```bash
psql "$DATABASE_URL" -f probes/12_long_running_transactions.sql
```

### All v1 probes

```bash
for f in probes/*.sql; do
  echo "=== $(basename "$f") ==="
  psql "$DATABASE_URL" -f "$f"
  echo
done
```

### With formatted output

```bash
psql "$DATABASE_URL" -x -f probes/00_instance_metadata.sql
```

### Saving output to JSON (requires psql 14+)

```bash
psql "$DATABASE_URL" -t -A \
  -c "SELECT json_agg(row_to_json(t)) FROM ($(cat probes/12_long_running_transactions.sql)) t;"
```

## Profile-Based Probe Selection

Not all probes need to run for every assessment. See `contracts/probe_registry.yaml` for the authoritative definition of which probes are included in each assessment profile.

## Prerequisites and Skip Handling

### pg_stat_statements probes (20–22)

These probes require the `pg_stat_statements` extension. Before running:

```sql
SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements';
```

If the extension is not installed, **skip probes 20–22**. Record that they were skipped (this feeds the `diagnostic_visibility_limited` finding).

### Replication probe (40)

The replication probe contains two queries: one for primaries, one for replicas. Check recovery state first:

```sql
SELECT pg_is_in_recovery();
```

- If `false` (primary): run the `pg_stat_replication` query
- If `true` (replica): run the `pg_last_xact_replay_timestamp()` query

### WAL stats (41)

The `pg_stat_wal` query (second query in 41) requires PostgreSQL 14+. On older versions, run only the `pg_stat_bgwriter` query (first query in 41). The probe will error on the second query; this is expected.

## Payload Normalization

When the results of these probes are stored as assessment evidence (whether by CLI or manually), normalize the output as follows:

### Canonical envelope

```json
{
  "probe_name": "long_running_transactions",
  "probe_version": "2026-03-20",
  "collected_at": "2026-03-20T20:15:00Z",
  "status": "success",
  "summary": { ... },
  "columns": ["pid", "usename", "xact_age", ...],
  "rows": [ ... ],
  "metadata": {
    "duration_ms": 14,
    "collector_version": "manual",
    "database_name": "postgres"
  }
}
```

### Normalization rules

| Type       | Rule                                                                 |
|------------|----------------------------------------------------------------------|
| NULLs      | Preserve as JSON `null`, not empty strings                           |
| Numerics   | Use numeric types, not strings (e.g., `18420` not `"18420"`)        |
| Intervals  | Convert to seconds as a numeric field (e.g., `xact_age_seconds`)   |
| Sizes      | Include raw byte values alongside `pg_size_pretty` formatted output |
| Timestamps | ISO 8601 format (`2026-03-20T20:15:00Z`)                           |
| Query text | Truncate to 1000 characters maximum                                  |

### Failed or skipped probes

Record failed or skipped probes with the same envelope structure:

```json
{
  "probe_name": "top_queries_total_time",
  "probe_version": "2026-03-20",
  "collected_at": "2026-03-20T20:15:00Z",
  "status": "skipped",
  "summary": {},
  "rows": [],
  "metadata": {
    "skip_reason": "pg_stat_statements extension not installed",
    "collector_version": "manual",
    "database_name": "postgres"
  }
}
```

For errors, use `"status": "failed"` and populate `error_text`.

## Interpretation Caveats

1. **Point-in-time snapshots.** Most probes capture a moment. Do not infer trends from a single run.
2. **Cumulative counters.** `database_activity` stats are cumulative since the last stats reset. Record the stats reset time if possible.
3. **Stats window matters.** Unused indexes and query stats are only meaningful if the stats window covers a representative workload period.
4. **Absence is not evidence.** No blocking chains at sample time does not mean blocking never occurs.
5. **Workload context matters.** A 500ms query is catastrophic in OLTP, normal in OLAP. Interpret all findings in the context of the workload classification.

## Adding New Probes

When adding a new probe:

1. Choose a number in the appropriate range for the domain
2. Add the SQL header comment with: probe name, purpose, prerequisites, profiles
3. Keep queries self-contained (no temp tables, no session state, no side effects)
4. Target `current_database()` where applicable
5. Use `LIMIT` to bound output size
6. Use `LEFT(query, N)` to truncate query text
7. Update `contracts/probe_registry.yaml` with the payload contract
8. Update `docs/07_probe_system.md` and `docs/11_probe_catalog.md`

## See Also

- `docs/07_probe_system.md` — probe model, profiles, and mappings
- `docs/11_probe_catalog.md` — detailed interpretation guidance per probe
- `contracts/probe_registry.yaml` — machine-readable payload contracts
- `docs/15_normalizer.md` — full normalization specification and interface contract
