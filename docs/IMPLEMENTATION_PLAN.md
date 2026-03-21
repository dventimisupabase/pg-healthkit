# Implementation Plan

This document describes a practical build order for turning the repository artifacts into a working v1 system.

The aim is to produce an end-to-end assessment loop quickly while minimizing architectural thrash.

## Objectives

A successful v1 should be able to:

- select probes by profile
- execute SQL probes
- normalize raw tabular output into canonical payloads
- validate payloads against probe contracts
- evaluate rules
- produce findings and score deltas
- emit a human-readable report
- persist or export results in a stable format

The initial implementation does not need:
- a polished UI
- sophisticated trend analysis
- historical benchmarking
- automatic remediation

## Recommended Build Order

Build in the order below.

### Phase 1+2 — Probe runner and normalization (combined deliverable)

Phases 1 and 2 from the original plan are combined into a single deliverable. The normalizer is lightweight enough to build alongside the runner, and having normalized output from the start avoids a throwaway raw-only output format.

**Goal:** A Go CLI that loads the probe registry, connects to a PostgreSQL database, executes probes filtered by profile, normalizes results into canonical payloads, validates against contracts, and emits JSON to stdout.

**Architecture:** Four internal packages (`registry`, `probe`, `normalize`, `validate`) wired together by a thin `main.go`. Contract-driven type coercion with probe-specific summary derivation functions. pgx for database access, yaml.v3 for registry parsing.

**Tech Stack:** Go 1.22+, pgx/v5, gopkg.in/yaml.v3, stdlib

**Key Reference Files:**
- `contracts/probe_registry.yaml` — canonical payload contracts
- `docs/15_normalizer.md` — normalization rules and summary derivation
- `probes/*.sql` — SQL probe files

Deliverables:
- a command that runs one or more probes
- normalized canonical payloads validated against contracts
- raw output fixtures and canonical output fixtures
- clear skipped and failed states

Success criteria:
- probes can be run deterministically against a target database
- each probe emits canonical payloads with stable field names
- zero-row, skipped, and failed paths are handled correctly
- canonical payloads validate cleanly
- skipped probes are explicit
- failures are inspectable

#### Phase 1+2 File Structure

```
cli/
  cmd/healthkit/main.go              # Entry point: flags, orchestration, JSON output
  internal/
    registry/
      registry.go                    # Parse probe_registry.yaml into Go structs
      registry_test.go               # Test parsing, profile filtering, prerequisites
    probe/
      runner.go                      # pgx connection, SQL execution, raw row capture
      runner_test.go                 # Integration tests (build-tagged)
    normalize/
      normalize.go                   # Generic type coercion + canonical envelope
      summary.go                     # Probe-specific summary derivation functions
      normalize_test.go              # Fixture-driven normalization tests
    validate/
      validate.go                    # Validate canonical payloads against contracts
      validate_test.go               # Valid/invalid payload tests
  testdata/
    raw/
      instance_metadata.json         # Raw pgx output fixture
      long_running_transactions.json
      connection_pressure.json
    canonical/
      instance_metadata.json         # Expected normalized payload
      long_running_transactions.json
      connection_pressure.json
  go.mod
  go.sum
```

#### Phase 1+2 Implementation Steps

Build in this order. Use TDD for the first 3 probes (vertical slice) to lock down types and interfaces. Then broaden to all 24 probes with integration tests.

1. Initialize Go module (`github.com/dventimisupabase/pg-healthkit/cli`), create stub files for all packages
2. Implement registry loader: parse `probe_registry.yaml` into Go structs, filter by profile, find by name. Test against the real registry file.
3. Implement probe runner: connect via pgx, read SQL files, execute queries, capture rows into `[]map[string]any`, track duration. Handle success/failed/skipped states. Integration test (build-tagged) against a real database.
4. Implement normalizer: generic type coercion (intervals→ms, sizes→bytes, numeric strings→numbers, query truncation→1000 chars, nulls→JSON null), canonical envelope per `docs/15_normalizer.md`, probe-specific summary derivation per the same doc. Start with `long_running_transactions`, `instance_metadata`, `connection_pressure`. Fixture-driven tests.
5. Implement validator: decode `payload_contract` YAML node, check required summary fields present, check required row fields present. Validation errors are warnings, not fatal.
6. Wire up `cmd/healthkit/main.go`: parse flags (`--dsn`, `--profile`, `--probes`, `--probes-dir`, `--registry`, `--timeout`), orchestrate prereq probes → main probes → normalize → validate → JSON to stdout. Pre-run `extensions_inventory` and `instance_metadata` for prerequisite checking; cache results to avoid double-running.
7. Implement remaining 21 probe summary derivation functions per `docs/15_normalizer.md`.
8. End-to-end smoke test: build binary, run all probes against a real database, verify JSON output.

### Phase 3 — Rule evaluation (Arena-side, SQL functions)
Implement as SQL functions in the Arena database:
- rule loading from `rules.yaml` (seed as reference data)
- profile filtering
- required-probe checks
- fact path resolution against stored evidence JSONB
- operator evaluation
- first-match case handling
- finding rendering
- score delta accumulation

> **Design decision:** Rule evaluation lives in the Arena (Supabase SQL functions), not in the CLI. This centralizes rule evolution, avoids CLI releases to update rules, and ensures findings can always be reproduced server-side. The CLI's `analyze` command triggers server-side evaluation.

Deliverables:
- SQL functions for rule evaluation and scoring
- finding and score views
- rule fixtures and tests (run against the database)

Success criteria:
- rules produce expected findings from canonical payloads
- skipped evidence does not cause false findings
- score deltas accumulate deterministically

### Phase 4 — Reporting
Implement:
- summary rendering from findings and scores
- report sections by domain
- evidence references in findings
- markdown output

Deliverables:
- report renderer
- markdown report template
- sample report fixtures

Success criteria:
- a completed run produces a readable report
- findings are traceable back to probe evidence
- scores are understandable, not opaque

### Phase 5 — Persistence integration
Implement one of:
- file-based export/import for local workflows
- database-backed persistence for assessments

Deliverables:
- serialization contract
- stored assessment results
- replayable artifacts

Success criteria:
- results can be revisited after execution
- findings and evidence remain inspectable

## Suggested CLI Milestones

Assuming a Go CLI integration path, implement these commands in sequence.

### Milestone 1
`health probe run`

Responsibilities:
- load registry
- choose profile
- execute probes
- emit raw or canonical JSON

### Milestone 2
`health normalize`

Responsibilities:
- take raw results
- emit canonical payloads

This can be separate initially even if later folded into `probe run`.

### Milestone 3
`health analyze`

Responsibilities:
- load canonical payloads
- apply rules
- emit findings and scores

### Milestone 4
`health report`

Responsibilities:
- render markdown or JSON summary from analysis outputs

### Milestone 5
`health full-run`

Responsibilities:
- orchestrate the full flow end-to-end

For v1, separate commands are useful because they make debugging much easier.

## Implementation Boundaries

Keep these boundaries clean.

### Probe runner
Should know:
- which SQL to run
- how to collect raw output
- why a probe was skipped

Should not know:
- severity logic
- score logic
- report rendering rules

### Normalizer
Should know:
- canonical field names
- type coercion rules
- summary field derivation

Should not know:
- business meaning of severity
- whether a finding is important

### Rule engine (Arena, SQL functions)
Should know:
- rule semantics
- JSONB field lookup against stored evidence
- score deltas

Should not know:
- how SQL was executed on the target database
- how fields were originally typed in raw output

Lives in the Arena, not the CLI. Triggered by the `analyze` endpoint.

### Reporter
Should know:
- how to render findings and scores clearly

Should not know:
- how to derive findings from evidence

## Recommended Test Strategy

Use fixtures aggressively.

### Probe fixtures
Store:
- raw SQL output examples
- skipped examples
- failed examples

### Normalization fixtures
Store:
- canonical payload outputs
- validation expectations

### Rule fixtures
Store:
- canonical payload bundles
- expected findings
- expected score deltas

### Report fixtures
Store:
- expected markdown output for representative scenarios

This enables both human review and agentic iteration.

## Repository Layout

```text
/probes
  *.sql

/contracts
  probe_registry.yaml
  rules.yaml

/docs
  methodology and spec files

/cli/cmd/healthkit        # Go: entry point
/cli/internal/registry    # Go: contract loader
/cli/internal/probe       # Go: probe runner
/cli/internal/normalize   # Go: normalizer + summary derivation
/cli/internal/validate    # Go: contract validator
/cli/testdata/raw         # fixtures: raw probe output
/cli/testdata/canonical   # fixtures: normalized payloads

/arena/supabase/migrations  # SQL: schema, functions, views
/arena/supabase/functions   # SQL: rule evaluation, scoring
/arena/testdata/rules       # fixtures: rule evaluation tests
/arena/testdata/reports     # fixtures: report output
```

## First Probe Set to Implement

Start with the highest-value probes first:

### Wave 1 — Generic (highest signal, fewest dependencies)
1. `instance_metadata`
2. `extensions_inventory`
3. `connection_pressure`
4. `long_running_transactions`
5. `lock_blocking_chains`
6. `largest_tables`
7. `dead_tuple_ratio`
8. `stale_maintenance`
9. `role_inventory`

### Wave 2 — Generic (baseline, lower priority)
10. `database_activity` (queries `pg_stat_database`, does not require pg_stat_statements)

### Wave 3 — Generic (requires pg_stat_statements)
11. `top_queries_total_time`
12. `top_queries_mean_latency`
13. `temp_spill_queries`

### Wave 4 — Generic (operational depth)
14. `replication_health`
15. `wal_checkpoint_health`
16. `unused_indexes`

### Wave 5 — Supabase-specific (critical)
17. `rls_policy_column_indexing` — arguably the highest-impact Supabase probe; implement early
18. `realtime_replication_slot_health`
19. `auth_schema_health`
20. `storage_objects_health`
21. `system_schema_bloat`

### Wave 6 — Supabase-specific (contextual)
22. `pg_cron_job_health`
23. `extension_version_health`
24. `pgvector_index_health`

For Supabase deployments, Wave 5 should be prioritized alongside or immediately after Wave 1, since `rls_policy_column_indexing` and `auth_schema_health` catch the most common Supabase-specific issues.

## First Rules to Implement

### Generic rules (first)
1. `long_running_transactions_detected`
2. `idle_in_transaction_sessions_detected`
3. `active_lock_blocking_detected`
4. `deadlocks_observed`
5. `high_connection_utilization`
6. `significant_temp_spill_activity`
7. `high_impact_query_total_time`
8. `high_latency_queries_detected`
9. `dead_tuple_accumulation_detected`
10. `stale_vacuum_or_analyze_detected`
11. `potentially_unused_large_indexes`
12. `replication_lag_elevated`
13. `checkpoint_pressure_detected`
14. `diagnostic_visibility_limited`
15. `diagnostic_configuration_weak`
16. `storage_concentration_risk`
17. `excessive_superuser_roles`

### Supabase rules (immediately after)
18. `rls_policy_columns_unindexed`
19. `auth_table_bloat_detected`
20. `system_schema_vacuum_stale`
21. `replication_slot_inactive_or_lagging`
22. `storage_soft_delete_pressure`
23. `pg_cron_job_failures`
24. `extension_version_outdated`
25. `pgvector_missing_index`
26. `pgvector_index_misconfigured`
27. `auth_session_explosion`
28. `storage_objects_bloat`

These are the best candidates for an early credible report. For Supabase assessments, rules 18–20 are as high-priority as the generic top 12.

## Definition of Done for v1

The v1 system is "done enough" when the following is true:

- a target profile can be selected (including `supabase_default`)
- probes run or skip deterministically (16 generic + 8 Supabase-specific = 24 total)
- canonical payloads validate against registry contracts
- rules produce stable findings
- domain scores are computed reproducibly
- a markdown report is produced
- evidence, findings, and scores can be inspected after the run
- for Supabase: system schema health is visible alongside user schema health

That is sufficient for operator use and for internal dogfooding.

## Risks to Manage

The main implementation risks are:

### Contract drift
Machine-readable files and code diverge.

Mitigation:
- validate payloads
- generate code from contracts where practical
- keep fixture tests close to the contracts

### Overengineering
Too much framework before end-to-end usefulness.

Mitigation:
- prioritize a thin vertical slice
- keep separate commands initially
- defer sophisticated features

### Hidden semantics
Important behavior is implied rather than encoded.

Mitigation:
- keep rules explicit
- keep normalized field names stable
- document units and thresholds directly

### Workload blindness
Rules interpreted without workload context.

Mitigation:
- require assessment profile
- preserve workload type in context
- keep some rules profile-limited

## Recommended First Vertical Slice

If only one thin slice is built first, make it:

- run `long_running_transactions`
- normalize payload
- evaluate `long_running_transactions_detected`
- render one finding in markdown

Then add:
- `connection_pressure`
- `idle_in_transaction_sessions_detected`

Then:
- `lock_blocking_chains`

This yields a usable concurrency-focused path quickly.

## Guidance for Agentic Execution

If using an agentic workflow, assign tasks in this order:

1. implement contract loader
2. implement one probe runner
3. implement one normalizer
4. implement one rule evaluator path
5. implement one markdown report path
6. generalize only after the vertical slice works

Require the agent to:
- preserve declared field names exactly
- add tests before broadening scope
- avoid embedding contract values in multiple places
- prefer readability over abstraction

That will reduce churn substantially.
