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

### Phase 3 — Rule evaluation
Implement:
- rule loading from `rules.yaml`
- profile filtering
- required-probe checks
- fact path resolution
- operator evaluation
- first-match case handling
- finding rendering
- score delta accumulation

Deliverables:
- rule engine package
- finding objects
- score accumulator
- rule fixtures and tests

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

### Rule engine
Should know:
- rule semantics
- field lookup
- score deltas

Should not know:
- how SQL was executed
- how fields were originally typed in raw output

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

/internal/probes
/internal/normalize
/internal/rules
/internal/report
/internal/contracts

/testdata/raw
/testdata/canonical
/testdata/rules
/testdata/reports
```

The exact layout can vary, but keeping contracts and fixtures explicit is important.

## First Probe Set to Implement

Start with the highest-value probes first:

1. `connection_pressure`
2. `long_running_transactions`
3. `lock_blocking_chains`
4. `top_queries_total_time`
5. `top_queries_mean_latency`
6. `dead_tuple_ratio`
7. `stale_maintenance`
8. `replication_health`

These give strong signal for reliability and performance with relatively direct interpretation.

Then add:
- `database_activity`
- `temp_spill_queries`
- `largest_tables`
- `unused_indexes`
- `wal_checkpoint_health`
- `instance_metadata`
- `extensions_inventory`

## First Rules to Implement

Start with the most actionable findings:

1. `long_running_transactions_detected`
2. `idle_in_transaction_sessions_detected`
3. `active_lock_blocking_detected`
4. `high_connection_utilization`
5. `high_latency_queries_detected`
6. `high_impact_query_total_time`
7. `dead_tuple_accumulation_detected`
8. `stale_vacuum_or_analyze_detected`
9. `replication_lag_elevated`

These are the best candidates for an early credible report.

## Definition of Done for v1

The v1 system is “done enough” when the following is true:

- a target profile can be selected
- probes run or skip deterministically
- canonical payloads validate against registry contracts
- rules produce stable findings
- domain scores are computed reproducibly
- a markdown report is produced
- evidence, findings, and scores can be inspected after the run

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
