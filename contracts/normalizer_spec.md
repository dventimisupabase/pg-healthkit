# Normalizer Specification

This document defines how raw SQL tabular output is transformed into the canonical probe payloads described in `probe_registry.yaml`.

The purpose of the normalizer layer is to create a stable contract between:

- probe execution
- evidence storage
- rule evaluation
- report rendering

The SQL runner may change implementation details over time. The normalizer must preserve payload shape stability.

## 1. Responsibilities

The normalizer is responsible for:

- parsing raw query results
- coercing values into canonical types
- constructing probe-specific `summary` objects
- truncating or sanitizing large text fields consistently
- emitting a predictable payload even when row counts are zero
- distinguishing success, skipped, and failed execution outcomes

The normalizer is **not** responsible for:

- evaluating rules
- assigning severity
- computing overall scores
- generating reports

## 2. Input Model

A probe executor should emit a raw result object with this shape:

```json
{
  "probe_name": "long_running_transactions",
  "probe_version": "2026-03-20",
  "status": "success",
  "columns": ["pid", "usename", "application_name", "state", "xact_age_seconds", "query"],
  "rows": [
    [12345, "app", "api", "idle in transaction", 18420, "BEGIN"]
  ],
  "metadata": {
    "duration_ms": 12,
    "database_name": "postgres",
    "collector_version": "0.1.0"
  }
}
```

The raw executor may also choose to emit rows as objects rather than arrays. Both are acceptable input formats, but the normalizer output must be canonical.

## 3. Output Model

The normalizer should emit a canonical evidence payload with this envelope:

```json
{
  "probe_name": "long_running_transactions",
  "probe_version": "2026-03-20",
  "status": "success",
  "summary": {
    "row_count": 1,
    "oldest_xact_age_seconds": 18420,
    "oldest_idle_xact_age_seconds": 18420
  },
  "rows": [
    {
      "pid": 12345,
      "usename": "app",
      "application_name": "api",
      "state": "idle in transaction",
      "xact_age_seconds": 18420,
      "query_age_seconds": 18410,
      "wait_event_type": "Client",
      "wait_event": "ClientRead",
      "query": "BEGIN"
    }
  ],
  "metadata": {
    "duration_ms": 12,
    "database_name": "postgres",
    "collector_version": "0.1.0"
  }
}
```

The canonical output must conform to the field names and types declared in `probe_registry.yaml`.

## 4. Execution States

A normalized probe must be in one of these states:

- `success`
- `skipped`
- `failed`

### Success
The SQL executed and the payload was normalized.

### Skipped
The probe was intentionally not executed, for example because:
- a required extension was missing
- the probe does not apply to the environment
- the selected profile excluded it

A skipped payload should not invent empty data. It should clearly indicate why the probe was skipped.

### Failed
The SQL ran or attempted to run, but execution or normalization failed unexpectedly.

## 5. Canonical Envelopes

### Success envelope

```json
{
  "probe_name": "<name>",
  "probe_version": "<version>",
  "status": "success",
  "summary": {},
  "rows": [],
  "metadata": {}
}
```

### Skipped envelope

```json
{
  "probe_name": "<name>",
  "probe_version": "<version>",
  "status": "skipped",
  "skip_reason": "missing_extension",
  "summary": {
    "row_count": 0
  },
  "rows": [],
  "metadata": {}
}
```

### Failed envelope

```json
{
  "probe_name": "<name>",
  "probe_version": "<version>",
  "status": "failed",
  "error": {
    "code": "execution_error",
    "message": "permission denied for relation pg_stat_statements"
  },
  "summary": {
    "row_count": 0
  },
  "rows": [],
  "metadata": {}
}
```

## 6. Generic Normalization Rules

### 6.1 Column naming
Normalized row keys must use the exact field names expected by `probe_registry.yaml`.

Do not expose raw SQL aliases that differ from the registry contract once normalization is complete.

### 6.2 Numeric coercion
Convert the following to numeric types where applicable:

- counts → integer
- percentages → number
- bytes → integer
- durations in ms/s → integer or number

Strings such as `"500"` should become `500` when the contract expects numeric values.

### 6.3 Interval coercion
PostgreSQL intervals must not remain as textual interval strings in normalized payloads when the registry expects a scalar duration.

Normalize to:
- milliseconds for lag or execution time fields ending in `_ms`
- seconds for age fields ending in `_seconds`

### 6.4 Null handling
Use `null` for missing or unknown scalar values.

Do not substitute:
- empty string
- `"N/A"`
- `"unknown"`

### 6.5 Boolean handling
Normalize booleans to `true` or `false`.

### 6.6 Query text
If query text is retained:
- preserve enough text for operator usefulness
- truncate consistently
- record truncation policy in metadata if needed

Recommended v1 policy:
- truncate at 1000 characters
- preserve original text only if storage policy allows

### 6.7 Size fields
Where the rule engine or registry expects numeric size fields, normalize to bytes.

Human-readable size strings like `12 GB` should not appear in normalized payloads.

### 6.8 Timestamps
Where timestamps are retained, emit ISO-8601 strings.

### 6.9 Zero-row probes
If a probe executes successfully but returns no rows:
- status remains `success`
- `rows` is `[]`
- `summary.row_count` is `0`
- any max/min fields should be `0` or `null` according to the registry contract

Prefer `0` for counts and `null` for unavailable scalar measures.

## 7. Summary Object Rules

Every probe should expose a `summary` object unless the registry explicitly says otherwise.

The `summary` object exists to provide stable scalar access for rule evaluation.

A normalizer must compute summary fields deterministically from the normalized rows, not from the raw untyped result.

Examples:
- `summary.row_count`
- `summary.top_mean_exec_time_ms`
- `summary.max_dead_tuple_pct`
- `summary.zero_scan_large_index_count`

## 8. Probe-Specific Summary Derivation

### instance_metadata
No derived `summary` required unless later added.
Use direct object fields and `settings`.

### extensions_inventory
Derive:
- `summary.extension_count`
- `summary.has_pg_stat_statements`
- `summary.missing_features`

For v1, `missing_features` should be `1` if `pg_stat_statements` is absent, else `0`.

### database_activity
No `rows` array is required if the probe is naturally a singleton object, but v1 may still emit object-style payloads.
Expose:
- `datname`
- `stats`

### connection_pressure
Derive:
- `summary.total_connections`
- `summary.active`
- `summary.idle`
- `summary.idle_in_transaction`
- `summary.max_connections`
- `summary.utilization_pct`

`utilization_pct = total_connections / max_connections * 100`

### long_running_transactions
Derive:
- `summary.row_count`
- `summary.oldest_xact_age_seconds`
- `summary.oldest_idle_xact_age_seconds`

The second value should be the maximum `xact_age_seconds` among rows where `state = "idle in transaction"`.

### lock_blocking_chains
Derive:
- `summary.blocking_pairs = len(rows)`

### top_queries_total_time
Derive:
- `summary.row_count`
- `summary.top_total_exec_time_ms`
- `summary.top_calls`

These values should come from the first row after sorting descending by `total_exec_time_ms`.

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
- `summary.stale_tables`
- `summary.tables_missing_autoanalyze`
- `summary.tables_over_1m_live_tup`

For v1:
- `stale_tables` means rows included in the normalized output because they met the stale filter
- `tables_missing_autoanalyze` means rows with `last_autoanalyze = null`
- `tables_over_1m_live_tup` means rows with `n_live_tup > 1000000`

### unused_indexes
Derive:
- `summary.row_count`
- `summary.zero_scan_large_index_count`

For v1, a “large index” should mean `index_bytes >= 104857600` (100 MiB), unless the registry is revised.

### replication_health
Derive:
- `summary.row_count`
- `summary.max_replay_lag_ms`

If replay lag is absent for all rows, emit `0` or `null` based on the registry contract. For the current registry, prefer `0`.

### wal_checkpoint_health
No generic `summary` object is required in the registry.
Expose:
- `bgwriter`
- optional `wal`

## 9. Determinism Requirements

Normalization should be deterministic.

Given the same raw result, the normalizer must produce the same canonical payload.

This matters for:
- reproducible findings
- testability
- diffing between runs

## 10. Forward Compatibility

The normalizer may add fields beyond the registry contract, but it must not:
- remove existing fields
- change field meaning
- change units
- rename fields silently

If a field contract changes, bump the contract version in the registry and adjust rules accordingly.

## 11. Validation

After normalization, validate the payload against the probe contract in `probe_registry.yaml`.

Validation failures should produce:
- `status: failed`, or
- a rejected upload in stricter environments

For v1, validation errors should be surfaced clearly with probe name, missing field, and expected type.

## 12. Recommended File Boundaries

A practical implementation should separate:

- SQL runner
- raw result adapter
- probe-specific normalizers
- contract validator

That keeps probe-specific logic small and testable.
