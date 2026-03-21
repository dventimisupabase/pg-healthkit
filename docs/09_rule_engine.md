# Rule Engine

## Purpose

Convert evidence into findings. The diagnostic layer is where most "health checks" fail — metrics alone are not enough. You need interpretation rules.

The rule engine sits between normalized probe evidence and human-actionable findings. It is intentionally declarative: SQL probes collect evidence, the rule engine interprets it, reporting renders the results.

See `contracts/rules.yaml` for the machine-readable rule definitions.

## Evaluation Model

The rule engine uses a declarative evaluation model. Understanding these mechanics is necessary for implementing or extending rules.

### Execution Flow

1. Load assessment context (persona, workload type, profile)
2. Load normalized probe payloads
3. Iterate through enabled rules for the active profile
4. Verify required probes are present
5. Evaluate rule cases in order
6. When a case matches, create the finding and apply score deltas
7. Continue to the next rule

Rules are independent from each other unless an implementation explicitly adds cross-rule logic later.

### Fact Resolution

Each condition references a fact using a `from` (probe name or `assessment_context`) and a `fact` (dot-path into the normalized payload):

```yaml
- fact: summary.oldest_xact_age_seconds
  from: long_running_transactions
  op: gt
  value: 3600
```

Dot-path resolution:

1. Start at the normalized object for the named source
2. Split the fact path on `.`
3. Traverse keys in order
4. If any key is missing, resolution returns "missing" — the condition evaluates false (not an error)

### Operators

The supported operators are intentionally small:

| Operator       | Meaning                                |
|----------------|----------------------------------------|
| `gt`, `gte`    | Greater than, greater than or equal    |
| `lt`, `lte`    | Less than, less than or equal          |
| `eq`, `neq`    | Equal, not equal (null-safe)           |
| `contains`     | String or array contains value         |
| `not_contains` | String or array does not contain value |
| `in`, `not_in` | Value in / not in a set                |
| `exists`       | Fact path resolves to a present value  |
| `not_exists`   | Fact path does not resolve             |
| `regex`        | Pattern match                          |

### Combinators

Conditions within a case use combinators:

- `all` — every child condition must evaluate true
- `any` — at least one child condition must evaluate true

Nested combinators are allowed but v1 should keep usage shallow.

### First-Match Evaluation

Rules use `mode: first_match`. Cases are evaluated in order; the first case whose condition evaluates true wins. Later cases in the same rule are ignored. This is useful when cases represent ordered severity bands (high → medium → low).

### Finding Construction

When a case matches, the engine:

1. Copies static finding metadata (key, domain, title, tags)
2. Renders templates using `${...}` interpolation from the matched probe payloads
3. Attaches evidence references to the supporting probes
4. Records matched case metadata for debugging

### Score Effects

Each matching case specifies additive score deltas:

```yaml
score_effects:
  concurrency: -20
  storage: -10
  availability: -8
```

These are applied to domain scores initialized at 100, then clamped to 0–100. Overall score computation happens outside the rule engine.

### Skip vs No-Match vs Error

These states must be distinct:

- **Skip** — rule disabled, profile doesn't apply, or required probe missing
- **No match** — rule evaluated, evidence existed, no case condition matched
- **Error** — evaluator logic fails or payload is malformed

This distinction matters for operator trust. "No finding" must not be conflated with "could not check."

## Design Principles

### 1. Many signals are workload-relative

- Low cache hit ratio is more meaningful for OLTP than OLAP
- Sequential scan prevalence is not inherently bad in analytics
- High `work_mem` may be reasonable at low concurrency and dangerous at high concurrency

Rules should include workload context in their conditions.

### 2. Many signals require history, not a single snapshot

- Growth rate
- Regression detection
- Trend in autovacuum lag
- Periodic saturation
- Capacity forecasting

These are outside v1 scope but the rule model should anticipate them.

### 3. Several checks are inherently low-confidence from catalog views alone

- Bloat estimation
- "Unused" indexes based on a short stats window
- Missing index claims without query evidence

Rules should include explicit confidence levels.

### 4. Rules should be explainable, not clever

Every rule should answer: what was observed, why it matters, what to do about it, and how confident we are.

### 5. Rules must diagnose root causes, not report symptoms

Findings should explain *why* something is happening, not just *that* it is happening. "Dead tuple accumulation detected" is a symptom. "Autovacuum cannot reclaim dead tuples because long-running transactions hold back the visibility horizon" is a root cause. Every finding template should include a `cause` that traces the observation back to a likely mechanism.

### 6. Recommendations must include tradeoffs

Remediation advice without tradeoffs is incomplete. For example, "drop this unused index" should note that the index may serve infrequent reporting queries. "Raise work_mem" should note the risk at high concurrency. If a recommendation has no meaningful downside, say so explicitly — that itself is useful information.

## V1 Rule Catalog

### long_running_transactions_detected

| Property       | Value                                                                                                                                             |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `long_running_transactions`                                                                                                                       |
| **Logic**      | high if oldest xact age > 1 hour; medium if > 15 minutes; low if > 5 minutes in OLTP profile. Increase severity if state is `idle in transaction` |
| **Domains**    | concurrency, storage, availability                                                                                                                |
| **Confidence** | high                                                                                                                                              |

### idle_in_transaction_sessions_detected

| Property       | Value                                                                                                     |
|----------------|-----------------------------------------------------------------------------------------------------------|
| **Inputs**     | `connection_pressure`, `long_running_transactions`                                                        |
| **Logic**      | high if idle-in-transaction count ≥ 3 and oldest > 15 minutes; medium if count ≥ 1 and oldest > 5 minutes |
| **Domains**    | concurrency, availability                                                                                 |
| **Confidence** | high                                                                                                      |

### active_lock_blocking_detected

| Property       | Value                                                                                                                                                      |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `lock_blocking_chains`                                                                                                                                     |
| **Logic**      | high if blocking chains present and blocked count > 3; medium if any blocking pair exists; critical if blockers include DDL or transaction age is very old |
| **Domains**    | concurrency, performance, availability                                                                                                                     |
| **Confidence** | high                                                                                                                                                       |

### deadlocks_observed

| Property       | Value                                                                               |
|----------------|-------------------------------------------------------------------------------------|
| **Inputs**     | `database_activity`                                                                 |
| **Logic**      | medium if deadlocks > 0; high if deadlocks exceed modest threshold for stats window |
| **Domains**    | concurrency, availability                                                           |
| **Confidence** | medium (stats window matters)                                                       |

### high_connection_utilization

| Property       | Value                                                                                                                                                |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `connection_pressure`, `instance_metadata`                                                                                                           |
| **Logic**      | medium if total_connections / max_connections > 80%; high if > 90%. Increase severity if active connections high and wait events indicate contention |
| **Domains**    | concurrency, availability                                                                                                                            |
| **Confidence** | medium                                                                                                                                               |

### significant_temp_spill_activity

| Property       | Value                                                                                                                                                                                                              |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `database_activity`, `temp_spill_queries`                                                                                                                                                                          |
| **Logic**      | medium if top queries repeatedly spill substantial temp blocks; high if spills are large and paired with high latency or high total time. **Downgrade in OLAP profile** unless interactive latency is an objective |
| **Domains**    | performance, efficiency, cost                                                                                                                                                                                      |
| **Confidence** | medium                                                                                                                                                                                                             |

### high_impact_query_total_time

| Property       | Value                                                                                                                                               |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `top_queries_total_time`                                                                                                                            |
| **Logic**      | medium if small number of queries dominate total execution time; high if one query is a clear outlier and business objective is performance or cost |
| **Domains**    | performance, efficiency, cost                                                                                                                       |
| **Confidence** | medium                                                                                                                                              |

### high_latency_queries_detected

| Property       | Value                                                                                                                                                     |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `top_queries_mean_latency`, `temp_spill_queries`, `lock_blocking_chains`                                                                                  |
| **Logic**      | medium/high based on workload profile and latency expectations. **Increase severity in OLTP; decrease severity in OLAP** unless user-facing path involved |
| **Domains**    | performance, concurrency                                                                                                                                  |
| **Confidence** | medium                                                                                                                                                    |

### dead_tuple_accumulation_detected

| Property       | Value                                                                                                                                                 |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `dead_tuple_ratio`, `long_running_transactions`, `largest_tables`                                                                                     |
| **Logic**      | medium if large active tables show substantial dead tuple percentage; high if paired with old transactions or stale vacuum. Deprioritize small tables |
| **Domains**    | storage, performance, availability                                                                                                                    |
| **Confidence** | high                                                                                                                                                  |

### stale_vacuum_or_analyze_detected

| Property       | Value                                                                                                                                        |
|----------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `stale_maintenance`, `dead_tuple_ratio`                                                                                                      |
| **Logic**      | medium if large/active relations have null or old autovacuum/autoanalyze; high if paired with dead tuple accumulation or poor query behavior |
| **Domains**    | storage, performance, operational hygiene                                                                                                    |
| **Confidence** | medium/high depending on table activity evidence                                                                                             |

### potentially_unused_large_indexes

| Property       | Value                                                                                                                                                                |
|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `unused_indexes`, `largest_tables`                                                                                                                                   |
| **Logic**      | low/medium if large indexes show zero scans. **Never high in v1** without longer stats horizon. Severity rises with index size and write-heavy table characteristics |
| **Domains**    | storage, efficiency, cost                                                                                                                                            |
| **Confidence** | medium/low                                                                                                                                                           |

### replication_lag_elevated

| Property       | Value                                                                                                                               |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `replication_health`                                                                                                                |
| **Logic**      | medium/high depending on lag magnitude and consistency. Increase severity if replicas serve reads or failover guarantees are strict |
| **Domains**    | availability, performance                                                                                                           |
| **Confidence** | medium/high                                                                                                                         |

### checkpoint_pressure_detected

| Property       | Value                                                                                                                                                                                                |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `wal_checkpoint_health`, `database_activity`, `instance_metadata`                                                                                                                                    |
| **Logic**      | medium if requested checkpoints are frequent relative to timed checkpoints; high if buffers_backend and backend fsync behavior indicate pressure. Increase severity if latency symptoms also present |
| **Domains**    | performance, efficiency, availability, cost                                                                                                                                                          |
| **Confidence** | medium                                                                                                                                                                                               |

### diagnostic_visibility_limited

| Property       | Value                                                                                             |
|----------------|---------------------------------------------------------------------------------------------------|
| **Inputs**     | `extensions_inventory`                                                                            |
| **Logic**      | low/medium if key observability extension absent. This is a **meta-finding**, not a system defect |
| **Domains**    | operational hygiene                                                                               |
| **Confidence** | high                                                                                              |

### diagnostic_configuration_weak

| Property       | Value                                                                                                                                                                                                                  |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `instance_metadata`                                                                                                                                                                                                    |
| **Logic**      | medium if `track_io_timing = off` AND `log_min_duration_statement = -1` AND `pg_stat_statements` absent; low if any one of these is suboptimal. Complements `diagnostic_visibility_limited` with configuration signals |
| **Domains**    | operational hygiene                                                                                                                                                                                                    |
| **Confidence** | high                                                                                                                                                                                                                   |

### storage_concentration_risk

| Property       | Value                                                                                                                 |
|----------------|-----------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `largest_tables`, `unused_indexes`                                                                                    |
| **Logic**      | low/medium if a few relations dominate storage. Becomes more relevant when cost or maintenance is a primary objective |
| **Domains**    | storage, cost, efficiency                                                                                             |
| **Confidence** | high                                                                                                                  |

### excessive_superuser_roles

| Property       | Value                                                                                                                                           |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `role_inventory`                                                                                                                                |
| **Logic**      | medium if > 2 roles have `SUPERUSER`; low if > 1 (beyond the default `postgres` role). Flag roles with `SUPERUSER` + `LOGIN` + no `VALID UNTIL` |
| **Domains**    | operational hygiene, availability                                                                                                               |
| **Confidence** | high                                                                                                                                            |

## Supabase-Specific Rules

### rls_policy_columns_unindexed

| Property       | Value                                                                    |
|----------------|--------------------------------------------------------------------------|
| **Inputs**     | `rls_policy_column_indexing`                                             |
| **Logic**      | high if > 5 unindexed RLS policy columns; medium if > 2 |
| **Domains**    | performance, efficiency                                                  |
| **Confidence** | high                                                                     |

This is possibly the single highest-impact Supabase-specific finding. RLS is enabled by default on all Supabase tables exposed through PostgREST. Missing indexes on columns referenced in USING clauses cause sequential scans on every API request through that table.

### replication_slot_inactive_or_lagging

| Property       | Value                                                                                                     |
|----------------|-----------------------------------------------------------------------------------------------------------|
| **Inputs**     | `realtime_replication_slot_health`                                                                        |
| **Logic**      | critical if inactive slot with lag > 1GB; high if lag > 500MB or inactive > 1 hour; medium if lag > 100MB |
| **Domains**    | availability, storage                                                                                     |
| **Confidence** | high                                                                                                      |

### auth_table_bloat_detected

| Property       | Value                                                                                                                                                   |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `auth_schema_health`                                                                                                                                    |
| **Logic**      | high if auth.sessions or auth.refresh_tokens dead_tuple_pct > 30% or row count > 5M with stale vacuum; medium if dead_tuple_pct > 10% or row count > 1M |
| **Domains**    | storage, performance, availability                                                                                                                      |
| **Confidence** | high                                                                                                                                                    |

### storage_soft_delete_pressure

| Property       | Value                                                                                     |
|----------------|-------------------------------------------------------------------------------------------|
| **Inputs**     | `storage_objects_health`                                                                  |
| **Logic**      | high if soft_deleted_ratio > 20% |
| **Domains**    | storage, cost                                                                             |
| **Confidence** | medium                                                                                    |

### system_schema_vacuum_stale

| Property       | Value                                                                                                                   |
|----------------|-------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `system_schema_bloat`                                                                                                   |
| **Logic**      | high if max dead_tuple_pct > 30% across system schema tables |
| **Domains**    | storage, performance, operational_hygiene                                                                               |
| **Confidence** | high                                                                                                                    |

### pool_mode_misconfiguration

| Property       | Value                                                                                                                                                                                           |
|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `pgbouncer_pool_health`                                                                                                                                                                         |
| **Logic**      | low if pool_mode = transaction (informational) |
| **Domains**    | performance, concurrency                                                                                                                                                                        |
| **Confidence** | medium                                                                                                                                                                                          |

### pool_contention_detected

| Property       | Value                                                                                                   |
|----------------|---------------------------------------------------------------------------------------------------------|
| **Inputs**     | `pgbouncer_pool_health`                                                                                 |
| **Logic**      | high if waiting clients > 10 and wait duration > 1 second; medium if any clients waiting                |
| **Domains**    | concurrency, performance                                                                                |
| **Confidence** | high                                                                                                    |

### auth_session_explosion

| Property       | Value                                                                                                                      |
|----------------|----------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `auth_schema_health`                                                                                                       |
| **Logic**      | high if auth.sessions row count > 10M; medium if > 5M with growth > 1M/week                                               |
| **Domains**    | storage, performance, availability                                                                                         |
| **Confidence** | high                                                                                                                       |

### pgvector_index_misconfigured

| Property       | Value                                                                                                                         |
|----------------|-------------------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `pgvector_index_health`                                                                                                       |
| **Logic**      | medium if HNSW index with default parameters on table > 500K rows; medium if IVFFlat with lists < sqrt(row_count)            |
| **Domains**    | performance, efficiency                                                                                                       |
| **Confidence** | medium                                                                                                                        |

### storage_objects_bloat

| Property       | Value                                                                                                     |
|----------------|-----------------------------------------------------------------------------------------------------------|
| **Inputs**     | `storage_objects_health`                                                                                  |
| **Logic**      | high if storage.objects dead_tuple_pct > 30% and size > 1GB; medium if dead_tuple_pct > 15%              |
| **Domains**    | storage, cost                                                                                             |
| **Confidence** | high                                                                                                      |

## Rule Attributes

Every rule must carry:

- **Workload context** — which profiles it applies to, whether severity varies by workload type
- **Confidence** — how trustworthy the inference is from available evidence
- **Prerequisites** — which probes must have succeeded
- **Whether history is required** — flag for future trend-based evolution. Rules that depend on growth rate, regression detection, trend in autovacuum lag, periodic saturation, or capacity forecasting should be marked `history_required: true` so the evaluator can skip them when only a single snapshot is available, rather than producing misleading findings

## What Rules Are Not

Rules produce **localized, mechanical insights** (findings). They are not the full interpretation layer.

Full interpretation also includes:
- Prioritization across findings
- Persona-aware framing
- Objective-aware weighting
- Cross-signal synthesis
- Narrative generation

That higher-order layer sits above the rule engine, typically in the reporting and review steps.
