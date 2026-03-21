# Normalizer

## Purpose

The normalizer transforms raw SQL tabular output into canonical probe payloads. It is the boundary between evidence collection (probes) and evidence interpretation (rules).

Without stable normalization, the rule engine cannot reliably resolve facts, the scoring model cannot compute domain scores, and reports cannot render findings consistently.

## Position in the Pipeline

```
SQL Probe → Raw Tabular Result → Normalizer → Canonical Payload → Rule Engine
```

The normalizer sits between the SQL runner and everything downstream. It is the contract enforcement point.

## Responsibilities

The normalizer is responsible for:

- Parsing raw query results (array rows or object rows)
- Coercing values into canonical types (numeric, boolean, null, ISO-8601)
- Constructing probe-specific `summary` objects for rule evaluation
- Truncating or sanitizing large text fields (query text at 1000 characters)
- Emitting a predictable payload even when row counts are zero
- Distinguishing `success`, `skipped`, and `failed` execution outcomes

The normalizer is **not** responsible for:

- Evaluating rules
- Assigning severity
- Computing scores
- Generating reports

## Canonical Envelope

Every normalized probe payload uses this envelope structure:

```json
{
  "probe_name": "<name>",
  "probe_version": "<version>",
  "status": "success | skipped | failed",
  "summary": { ... },
  "rows": [ ... ],
  "metadata": {
    "duration_ms": 14,
    "database_name": "postgres",
    "server_version_num": 170004,
    "collector_version": "0.1.0",
    "normalizer_version": "0.1.0",
    "contract_version": "v1",
    "probe_hash": "sha256:...",
    "warnings": []
  }
}
```

Skipped probes use `"status": "skipped"` with a `skip_reason` field. Failed probes use `"status": "failed"` with an `error` object. Both still emit `summary` and `rows` (empty).

## Type Coercion Rules

| Source Type          | Target                  | Rule                                            |
|----------------------|-------------------------|-------------------------------------------------|
| NULLs                | JSON `null`             | Never substitute empty strings or `"N/A"`       |
| Numeric strings      | Integer or number       | `"500"` → `500`                                 |
| PostgreSQL intervals | Seconds or milliseconds | Use `_seconds` or `_ms` suffix per registry     |
| Size values          | Bytes (integer)         | Never use human-readable strings like `"12 GB"` |
| Booleans             | `true` / `false`        | Normalize from PostgreSQL `t`/`f` if needed     |
| Timestamps           | ISO-8601 strings        | `"2026-03-20T20:15:00Z"`                        |
| Query text           | Truncated string        | 1000 character maximum                          |

## Summary Object

Every probe exposes a `summary` object with stable scalar fields for rule evaluation. The normalizer computes summary fields deterministically from normalized rows, not from raw untyped results.

Examples:

- `summary.row_count` — number of rows returned
- `summary.oldest_xact_age_seconds` — from `long_running_transactions`
- `summary.max_dead_tuple_pct` — from `dead_tuple_ratio`
- `summary.utilization_pct` — from `connection_pressure`
- `summary.zero_scan_large_index_count` — from `unused_indexes`

These are the fields that `rules.yaml` resolves via dot-path (e.g., `fact: summary.oldest_xact_age_seconds`).

## Zero-Row Handling

If a probe executes successfully but returns no rows:

- `status` remains `"success"`
- `rows` is `[]`
- `summary.row_count` is `0`
- Max/min fields are `0` or `null` per the registry contract

This is important: zero rows is a valid observation, not a failure.

## Determinism

Given the same raw result, the normalizer must produce the same canonical payload. This matters for reproducible findings, testability, and diffing between assessment runs.

## Interface Boundary

The normalizer defines a clean boundary between two components:

**SQL Runner** — executes probes, captures raw output, represents skip/fail states. Makes no rule-level decisions.

**Normalizer** — converts raw rows to named objects, coerces types, derives summaries, validates against registry. Makes no severity or scoring decisions.

The suggested Go interface:

```go
type Normalizer interface {
    Normalize(raw RawProbeResult) (CanonicalProbePayload, error)
}
```

A registry-aware variant:

```go
type RegistryAwareNormalizer interface {
    NormalizeWithContract(probeName string, raw RawProbeResult, contract ProbeContract) (CanonicalProbePayload, error)
}
```

## Validation

After normalization, validate the payload against `probe_registry.yaml`. Validation failures should produce `status: failed` or a rejected upload. For v1, surface errors clearly with probe name, missing field, and expected type.

## Forward Compatibility

The normalizer may add fields beyond the registry contract, but must not remove existing fields, change field meaning or units, or rename fields silently. If a contract changes, bump the version in the registry and adjust rules accordingly.

## Probe-Specific Summary Derivation

### instance_metadata
Derive:
- `summary.track_io_timing` — value of the `track_io_timing` setting (string: `"on"` or `"off"`)
- `summary.log_min_duration_statement` — value of the `log_min_duration_statement` setting (coerce to integer: `-1` means disabled)
- `summary.random_page_cost` — value of the `random_page_cost` setting (string)
- `summary.shared_preload_libraries` — value of the `shared_preload_libraries` setting (string)

### extensions_inventory
Derive:
- `summary.extension_count`
- `summary.has_pg_stat_statements`
- `summary.missing_features` — `1` if `pg_stat_statements` is absent, else `0`

### database_activity
No `rows` array is required if the probe is naturally a singleton object. Expose `datname` and `stats`.

### connection_pressure
Derive:
- `summary.total_connections`
- `summary.active`
- `summary.idle`
- `summary.idle_in_transaction`
- `summary.max_connections`
- `summary.utilization_pct` = `total_connections / max_connections * 100`

The registry contract also requires a `states` array. The SQL probe's Part 2 (grouped by state/wait event) is commented out. The normalizer should synthesize the `states` array from Part 1 by grouping the summary counts into objects:

```json
"states": [
  { "state": "active", "count": 5 },
  { "state": "idle", "count": 12 },
  { "state": "idle in transaction", "count": 2 }
]
```

If Part 2 is uncommented in a future version, the normalizer should use its richer output directly instead.

### long_running_transactions
Derive:
- `summary.row_count`
- `summary.oldest_xact_age_seconds`
- `summary.oldest_idle_xact_age_seconds` — max `xact_age_seconds` among rows where `state = "idle in transaction"`

### lock_blocking_chains
Derive:
- `summary.blocking_pairs` = `len(rows)`

### top_queries_total_time
Derive:
- `summary.row_count`
- `summary.top_total_exec_time_ms`
- `summary.top_calls`

Values come from the first row after sorting descending by `total_exec_time_ms`.

### top_queries_mean_latency
Derive:
- `summary.row_count`
- `summary.top_mean_exec_time_ms`

### temp_spill_queries
Derive:
- `summary.row_count`
- `summary.max_temp_blks_written`

### largest_tables
Derive:
- `summary.row_count`
- `summary.top_relation_total_bytes`

### dead_tuple_ratio
Derive:
- `summary.row_count`
- `summary.max_dead_tuple_pct`

### stale_maintenance
Derive:
- `summary.row_count`
- `summary.stale_tables` — rows that met the stale filter
- `summary.tables_missing_autoanalyze` — rows with `last_autoanalyze = null`
- `summary.tables_over_1m_live_tup` — rows with `n_live_tup > 1000000`

### unused_indexes
Derive:
- `summary.row_count`
- `summary.zero_scan_large_index_count` — "large" means `index_bytes >= 104857600` (100 MiB)

### replication_health
Derive:
- `summary.row_count`
- `summary.max_replay_lag_ms` — if replay lag is absent for all rows, emit `0`

### role_inventory
Derive:
- `summary.row_count`
- `summary.superuser_count` — count of rows where `rolsuper = true`

### wal_checkpoint_health
No generic `summary` required. Expose `bgwriter` and optional `wal`.

## Raw Input Contract

The SQL runner must produce a raw probe result:

```json
{
  "probe_name": "top_queries_mean_latency",
  "probe_version": "2026-03-20",
  "status": "success",
  "columns": ["queryid", "calls", "mean_exec_time_ms", "query"],
  "rows": [["777", 62, 933.2, "select ..."]],
  "metadata": {
    "duration_ms": 18,
    "database_name": "postgres",
    "collector_version": "0.1.0"
  }
}
```

Rows may be emitted as arrays (with `columns`) or as objects. Both are acceptable.

## Error Handling

**Recoverable issues** (e.g., unexpected null in a nullable column): coerce to null, record a warning in metadata, continue.

**Non-recoverable issues** (e.g., required numeric field cannot be parsed): emit `status: failed`, preserve error details, do not emit a partial success payload.

## Go Interface

```go
type RawProbeResult struct {
    ProbeName    string
    ProbeVersion string
    Status       string
    Columns      []string
    Rows         any
    Metadata     map[string]any
    SkipReason   string
    Error        map[string]any
}

type CanonicalProbePayload struct {
    ProbeName    string
    ProbeVersion string
    Status       string
    Summary      map[string]any
    Rows         []map[string]any
    Metadata     map[string]any
    SkipReason   string
    Error        map[string]any
}
```

## Example Transformation

### Raw input
```json
{
  "probe_name": "unused_indexes",
  "probe_version": "2026-03-20",
  "status": "success",
  "columns": ["schemaname", "table_name", "index_name", "idx_scan", "index_bytes"],
  "rows": [
    ["public", "orders", "orders_legacy_status_idx", "0", "125829120"],
    ["public", "events", "events_tmp_idx", "4", "33554432"]
  ],
  "metadata": { "duration_ms": 7, "collector_version": "0.1.0" }
}
```

### Canonical output
```json
{
  "probe_name": "unused_indexes",
  "probe_version": "2026-03-20",
  "status": "success",
  "summary": {
    "row_count": 2,
    "zero_scan_large_index_count": 1
  },
  "rows": [
    { "schemaname": "public", "table_name": "orders", "index_name": "orders_legacy_status_idx", "idx_scan": 0, "index_bytes": 125829120 },
    { "schemaname": "public", "table_name": "events", "index_name": "events_tmp_idx", "idx_scan": 4, "index_bytes": 33554432 }
  ],
  "metadata": {
    "duration_ms": 7,
    "collector_version": "0.1.0",
    "normalizer_version": "0.1.0",
    "contract_version": "v1",
    "warnings": []
  }
}
```

## Testing Guidance

Each probe should have at least three tests:
1. Success case with representative rows
2. Success case with zero rows
3. Skipped or failed case

For probes with summary derivation, add tests for null values, edge thresholds, and mixed-type raw values.
