# Normalizer Interface Contract

This document defines the interface boundary between the SQL runner and the payload normalizer.

The goal is to make implementation straightforward in Go, while keeping the contract simple enough for ad hoc execution from `psql` or similar tooling.

## 1. Conceptual Pipeline

The expected data flow is:

1. Select probe from registry
2. Execute SQL
3. Capture raw result
4. Normalize raw result into canonical payload
5. Validate canonical payload against `probe_registry.yaml`
6. Persist evidence
7. Evaluate rules

## 2. Input Contract: Raw Probe Result

The SQL runner must produce a raw probe result object.

### Required fields

```json
{
  "probe_name": "top_queries_mean_latency",
  "probe_version": "2026-03-20",
  "status": "success",
  "columns": ["queryid", "calls", "mean_exec_time_ms", "max_exec_time_ms", "stddev_exec_time_ms", "query"],
  "rows": [
    ["777", 62, 933.2, 4102.8, 551.4, "select ..."]
  ],
  "metadata": {
    "duration_ms": 18,
    "database_name": "postgres",
    "collector_version": "0.1.0"
  }
}
```

### Field definitions

- `probe_name`: must match a probe in `probe_registry.yaml`
- `probe_version`: version string for the SQL/probe definition
- `status`: one of `success`, `skipped`, `failed`
- `columns`: ordered list of output column names
- `rows`: raw tabular data
- `metadata`: executor metadata

### Allowed row representations

The runner may emit one of these row formats:

#### Array rows
```json
{
  "columns": ["pid", "usename"],
  "rows": [
    [123, "app"]
  ]
}
```

#### Object rows
```json
{
  "rows": [
    {"pid": 123, "usename": "app"}
  ]
}
```

If object rows are used, `columns` may still be emitted for consistency, but the normalizer should prefer object keys.

## 3. Skipped and Failed Raw Results

### Skipped
```json
{
  "probe_name": "top_queries_total_time",
  "probe_version": "2026-03-20",
  "status": "skipped",
  "skip_reason": "missing_extension",
  "metadata": {
    "collector_version": "0.1.0"
  }
}
```

### Failed
```json
{
  "probe_name": "top_queries_total_time",
  "probe_version": "2026-03-20",
  "status": "failed",
  "error": {
    "code": "execution_error",
    "message": "relation pg_stat_statements does not exist"
  },
  "metadata": {
    "collector_version": "0.1.0"
  }
}
```

## 4. Output Contract: Canonical Probe Payload

The normalizer must output a canonical payload that matches the registry.

### Standard envelope

```json
{
  "probe_name": "top_queries_mean_latency",
  "probe_version": "2026-03-20",
  "status": "success",
  "summary": {
    "row_count": 1,
    "top_mean_exec_time_ms": 933.2
  },
  "rows": [
    {
      "queryid": "777",
      "calls": 62,
      "mean_exec_time_ms": 933.2,
      "max_exec_time_ms": 4102.8,
      "stddev_exec_time_ms": 551.4,
      "query": "select ..."
    }
  ],
  "metadata": {
    "duration_ms": 18,
    "database_name": "postgres",
    "collector_version": "0.1.0"
  }
}
```

## 5. Interface Semantics

### SQL runner responsibilities
The runner must:
- select the SQL for a named probe
- execute it against the target
- capture tabular output and metadata
- represent skipped and failed states explicitly
- avoid making rule-level decisions

### Normalizer responsibilities
The normalizer must:
- convert raw rows to named object rows
- coerce types
- derive summary fields
- apply truncation or sanitization rules
- validate against the registry contract
- emit canonical payloads

### Registry responsibilities
The registry defines:
- expected probe names
- required fields
- field types
- summary fields
- supported findings and score domains

## 6. Probe Resolution

The interface assumes the probe is selected by registry key.

Pseudo-contract:

```text
Normalize(probe_name, raw_probe_result) -> canonical_payload
```

The implementation should reject mismatches where:
- `probe_name` does not exist in the registry
- raw result uses a different probe name than requested

## 7. Error Handling Contract

### Recoverable normalization issue
Example:
- one nullable column contains an unexpected string

Recommended behavior:
- coerce to null if safe
- record a warning in metadata
- continue

### Non-recoverable normalization issue
Example:
- a required numeric field cannot be parsed
- the payload fails contract validation in a required field

Recommended behavior:
- emit `status: failed`
- preserve original error details
- do not emit a partial success payload

## 8. Metadata Contract

The runner and normalizer should preserve a minimal metadata shape.

Recommended metadata fields:

```json
{
  "duration_ms": 18,
  "database_name": "postgres",
  "collector_version": "0.1.0",
  "normalizer_version": "0.1.0",
  "contract_version": "v1",
  "warnings": []
}
```

Warnings should be non-fatal normalization notes, for example:
- query text truncated
- invalid nullable field coerced to null
- optional WAL block unavailable on this Postgres version

## 9. Example Transformation

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
  "metadata": {
    "duration_ms": 7,
    "collector_version": "0.1.0"
  }
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
    {
      "schemaname": "public",
      "table_name": "orders",
      "index_name": "orders_legacy_status_idx",
      "idx_scan": 0,
      "index_bytes": 125829120
    },
    {
      "schemaname": "public",
      "table_name": "events",
      "index_name": "events_tmp_idx",
      "idx_scan": 4,
      "index_bytes": 33554432
    }
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

## 10. Testing Guidance

Each probe should have at least three tests:

1. success case with representative rows
2. success case with zero rows
3. skipped or failed case

For probes with summary derivation, add tests for:
- null values
- edge thresholds
- mixed-type raw values

## 11. Suggested Go Interfaces

A reasonable v1 shape would be:

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

type Normalizer interface {
    Normalize(raw RawProbeResult) (CanonicalProbePayload, error)
}
```

A registry-aware variant would be:

```go
type RegistryAwareNormalizer interface {
    NormalizeWithContract(probeName string, raw RawProbeResult, contract ProbeContract) (CanonicalProbePayload, error)
}
```

## 12. Practical Advice

Keep the normalizer boring.

Do not embed:
- business severity logic
- scoring rules
- reporting decisions

Its job is to create clean, stable evidence objects. That is enough.
