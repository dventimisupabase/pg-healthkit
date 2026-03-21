# Phase 1 Design: CLI Probe Runner

## Scope

This design covers Implementation Plan Phases 1 and 2 (probe runner + normalization) as a single deliverable, since the normalizer is lightweight enough to build alongside the runner. A Go CLI that loads the probe registry, connects to a target PostgreSQL database, executes probes filtered by assessment profile, normalizes results into canonical payloads, validates against contracts, and emits JSON to stdout.

## Architecture

### Module

`github.com/dventimisupabase/pg-healthkit`

### Dependencies

- `github.com/jackc/pgx/v5` — PostgreSQL driver
- `gopkg.in/yaml.v3` — YAML parsing
- Go stdlib for everything else

### Package Layout

```
cli/
  cmd/healthkit/main.go            # entry point: parse flags, orchestrate
  internal/
    registry/
      registry.go                  # parse probe_registry.yaml → []Probe
      registry_test.go
    probe/
      runner.go                    # connect via pgx, execute SQL, return raw rows
      runner_test.go
    normalize/
      normalize.go                 # raw rows → canonical payload per contract
      normalize_test.go
    validate/
      validate.go                  # canonical payload → check against contract
      validate_test.go
  testdata/
    raw/                           # fixture: raw probe output (JSON)
    canonical/                     # fixture: expected normalized payloads (JSON)
  go.mod
```

### Data Flow

```
probe_registry.yaml
        │
        ▼
   registry.Load()  →  []Probe (filtered by profile)
        │
        ▼
   probe.Run(db, probe)  →  RawResult{Rows, Error, Skipped}
        │
        ▼
   normalize.Normalize(probe, rawResult)  →  CanonicalPayload
        │
        ▼
   validate.Validate(probe, payload)  →  []ValidationError
        │
        ▼
   JSON to stdout
```

## Key Types

### registry.Probe

Parsed from `probe_registry.yaml`. Fields: name, version, enabled, profiles, category, sql_file, prerequisites, payload_contract (field names and types), summary_fields, normalization guidance.

### probe.RawResult

```go
type RawResult struct {
    ProbeName  string
    Rows       []map[string]any
    Status     string // "success", "failed", "skipped"
    DurationMs int64  // wall-clock execution time
    Error      error
    SkipReason string // for skipped probes
}
```

### normalize.CanonicalPayload

Aligned with `docs/15_normalizer.md` canonical envelope:

```go
type CanonicalPayload struct {
    ProbeName    string         `json:"probe_name"`
    ProbeVersion string         `json:"probe_version"`
    Status       string         `json:"status"`
    Summary      map[string]any `json:"summary"`
    Rows         []map[string]any `json:"rows"`
    SkipReason   string         `json:"skip_reason,omitempty"`
    Error        *ProbeError    `json:"error,omitempty"`
    Metadata     PayloadMetadata `json:"metadata"`
    ValidationErrors []string   `json:"validation_errors,omitempty"`
}

type PayloadMetadata struct {
    DurationMs       int64    `json:"duration_ms"`
    DatabaseName     string   `json:"database_name"`
    ServerVersionNum int      `json:"server_version_num"`
    CollectorVersion string   `json:"collector_version"`
    NormalizerVersion string  `json:"normalizer_version"`
    ContractVersion  string   `json:"contract_version"`
    ProbeHash        string   `json:"probe_hash"`
    Warnings         []string `json:"warnings"`
}

type ProbeError struct {
    Message string `json:"message"`
    Code    string `json:"code,omitempty"`
}
```

### validate.ValidationError

```go
type ValidationError struct {
    Field    string
    Expected string
    Actual   string
    Message  string
}
```

## Probe Execution Model

### Connection

Single `pgx.Conn` (not a pool). Connection string via `--dsn` flag or `DATABASE_URL` env var.

### Probe Selection

1. Load `probe_registry.yaml`
2. Filter by `--profile` flag (default: `default`)
3. Only include probes where `enabled: true`
4. Check prerequisites against target DB state

### Prerequisite Checking

`instance_metadata` runs first. Its results (extensions, config values, replica status) feed prerequisite checks for all subsequent probes. For example, probes requiring `pg_stat_statements` are skipped if the extension isn't loaded.

### Execution Per Probe

1. Read SQL from `probes/` directory (path from registry `sql_file` field)
2. Execute via pgx, scan all rows into `[]map[string]any`
3. Success → `RawResult{Rows: [...], Status: "success"}`
4. SQL error → `RawResult{Error: err, Status: "failed"}`
5. Prerequisite not met → `RawResult{Status: "skipped", Reason: "..."}`

### CLI Flags

- `--dsn` — connection string (falls back to `DATABASE_URL` env)
- `--profile` — assessment profile (default: `default`)
- `--probes` — optional comma-separated probe names to run
- `--probes-dir` — path to SQL files (default: `../probes/`)
- `--registry` — path to probe_registry.yaml (default: `../contracts/probe_registry.yaml`)
- `--timeout` — per-probe execution timeout (default: `30s`)

### Error Handling

- **Connection failure** (refused, auth error): CLI exits immediately with a non-zero exit code and error message to stderr. No probes are attempted.
- **Per-probe SQL error:** Probe is marked `failed` with the error captured. Execution continues with remaining probes.
- **Per-probe timeout:** Treated as a failure. The probe's context is cancelled after `--timeout` duration.
- **Connection drop mid-run:** Remaining probes are marked `failed`. Partial results are still emitted.

## Normalization

The normalizer has two layers: **generic type coercion** (contract-driven, applies to all probes) and **summary derivation** (probe-specific logic defined in `docs/15_normalizer.md`).

### Generic Type Coercion (Contract-Driven)

- **Intervals → seconds or milliseconds** per field suffix (`_seconds`, `_ms`) in the registry
- **Sizes → bytes** (e.g., `128 MB` → `134217728`)
- **Numeric strings → numbers** (e.g., `"42"` → `42`)
- **Booleans → `true`/`false`** (normalize PostgreSQL `t`/`f`)
- **Timestamps → ISO-8601 strings**
- **Query text → truncated to 1000 characters**
- **Null handling:** NULL → JSON `null`, never omitted
- **Field naming:** exact match to `payload_contract` field names

### Summary Derivation (Probe-Specific)

Summary fields require per-probe logic (e.g., `oldest_xact_age_seconds = max(xact_age_seconds)`, `utilization_pct = total_connections / max_connections * 100`). This logic is defined in `docs/15_normalizer.md` and implemented as a summary derivation function per probe. The registry's `summary_fields` list declares which fields exist; the normalizer doc defines how to compute them.

Adding a new probe requires: a SQL file, a registry entry, and a summary derivation function in the normalizer. The type coercion and envelope construction are generic.

### Non-Tabular Probes

Some probes (`instance_metadata`, `extensions_inventory`, `database_activity`) produce singleton or structured results rather than row arrays. The normalizer handles these by: (1) treating single-row results as the source for summary fields, and (2) still emitting a `rows` array (with one element for singletons) for uniform downstream handling. The `payload_contract` in the registry defines the expected shape.

## Validation

Checks normalized payloads against the contract:

- All declared fields present
- Types match (string, number, boolean, array)
- Summary fields populated (or null)
- No undeclared fields

Validation errors are warnings, not fatal. The payload is emitted with a `validation_errors` array. This keeps the pipeline inspectable rather than brittle.

## Output

Array of canonical payload envelopes, one per probe, printed as JSON to stdout. Failed and skipped probes are included with their status — nothing is silently dropped.

```json
[
  {
    "probe_name": "instance_metadata",
    "probe_version": "1.0.0",
    "status": "success",
    "summary": { "track_io_timing": "on", "shared_preload_libraries": "pg_stat_statements" },
    "rows": [ { ... } ],
    "metadata": {
      "duration_ms": 12,
      "database_name": "postgres",
      "server_version_num": 170004,
      "collector_version": "0.1.0",
      "normalizer_version": "0.1.0",
      "contract_version": "v1",
      "probe_hash": "sha256:abc123...",
      "warnings": []
    }
  },
  {
    "probe_name": "long_running_transactions",
    "probe_version": "1.0.0",
    "status": "success",
    "summary": { "row_count": 3, "oldest_xact_age_seconds": 45 },
    "rows": [ ... ],
    "metadata": { ... }
  },
  {
    "probe_name": "top_queries_total_time",
    "probe_version": "1.0.0",
    "status": "skipped",
    "skip_reason": "prerequisite not met: pg_stat_statements extension not loaded",
    "summary": {},
    "rows": [],
    "metadata": { ... }
  }
]
```

## Testing Strategy

### Registry Tests

Load the real `probe_registry.yaml`. Verify all 24 probes parse. Test profile filtering for each of the 5 profiles.

### Normalization Tests (Fixture-Driven)

For each probe, store raw input JSON and expected canonical output JSON in `testdata/`. Assert `normalize.Normalize()` produces the expected output. Cover: success with rows, success with zero rows, null field handling, interval/size coercion.

### Validation Tests

Feed valid and invalid payloads. Assert correct errors for: missing fields, wrong types, undeclared fields.

### Integration Tests (Build-Tagged)

`//go:build integration` — require a real PostgreSQL database. Test the full pipeline: connect → execute → normalize → validate. Not run in CI by default.

### First Fixtures

1. `instance_metadata` (prerequisite provider)
2. `long_running_transactions` (vertical slice)
3. `connection_pressure` (second probe for breadth)

## First Vertical Slice

Build order within Phase 1:

1. `go.mod` and package scaffolding
2. `registry` package — parse probe_registry.yaml
3. `probe` package — execute one probe (long_running_transactions)
4. `normalize` package — normalize its output
5. `validate` package — validate against contract
6. `cmd/healthkit/main.go` — wire it together, JSON to stdout
7. Add `instance_metadata` for prerequisite checking
8. Generalize to all probes

## What's Deferred

- Arena-side work (rule evaluation, scoring, persistence, reporting)
- CLI framework (cobra, subcommands)
- Arena upload
- Multiple output formats
- Trend analysis, historical benchmarking
