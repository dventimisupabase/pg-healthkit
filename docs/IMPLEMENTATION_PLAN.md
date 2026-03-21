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

### Phase 1 — Probe runner
Implement:
- probe discovery from `probe_registry.yaml`
- profile-based selection
- prerequisite checks
- SQL execution
- raw result capture

Deliverables:
- a command that runs one or more probes
- raw output fixtures
- clear skipped and failed states

Success criteria:
- probes can be run deterministically against a target database
- skipped probes are explicit
- failures are inspectable

### Phase 2 — Normalization
Implement:
- raw row-to-object conversion
- type coercion
- summary field derivation
- canonical payload envelopes
- payload validation against `probe_registry.yaml`

Deliverables:
- normalizer package
- contract validator
- fixture-driven tests per probe

Success criteria:
- each probe emits canonical payloads with stable field names
- zero-row, skipped, and failed paths are handled correctly
- canonical payloads validate cleanly

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

## Suggested Repository Layout

A likely implementation layout could be:

```text
/probes
  *.sql

/contracts
  probe_registry.yaml
  rules.yaml

/docs
  methodology and spec files

/cli/internal/probes      # Go: probe runner
/cli/internal/normalize   # Go: normalizer
/cli/internal/contracts   # Go: contract loader/validator
/cli/testdata/raw         # fixtures: raw probe output
/cli/testdata/canonical   # fixtures: normalized payloads

/arena/supabase/migrations  # SQL: schema, functions, views
/arena/supabase/functions   # SQL: rule evaluation, scoring
/arena/testdata/rules       # fixtures: rule evaluation tests
/arena/testdata/reports     # fixtures: report output
```

The exact layout can vary, but keeping contracts and fixtures explicit is important.

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
22. `pgbouncer_pool_health`

### Wave 6 — Supabase-specific (contextual)
23. `pg_cron_job_health`
24. `extension_version_health`
25. `pgvector_index_health`

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
23. `pool_mode_misconfiguration`
24. `pg_cron_job_failures`
25. `extension_version_outdated`
26. `pgvector_missing_index`
27. `pgvector_index_misconfigured`
28. `pool_contention_detected`
29. `auth_session_explosion`
30. `storage_objects_bloat`

These are the best candidates for an early credible report. For Supabase assessments, rules 18–20 are as high-priority as the generic top 12.

## Definition of Done for v1

The v1 system is “done enough” when the following is true:

- a target profile can be selected (including `supabase_default`)
- probes run or skip deterministically (16 generic + 9 Supabase-specific = 25 total)
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
