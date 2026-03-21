# Rule Engine

## Purpose

Convert evidence into findings. The diagnostic layer is where most "health checks" fail — metrics alone are not enough. You need interpretation rules.

The rule engine sits between normalized probe evidence and human-actionable findings. It is intentionally declarative: SQL probes collect evidence, the rule engine interprets it, reporting renders the results.

See `rules.yaml` for the machine-readable rule definitions and `rules.md` for the evaluation semantics.

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

### storage_concentration_risk

| Property       | Value                                                                                                                 |
|----------------|-----------------------------------------------------------------------------------------------------------------------|
| **Inputs**     | `largest_tables`, `unused_indexes`                                                                                    |
| **Logic**      | low/medium if a few relations dominate storage. Becomes more relevant when cost or maintenance is a primary objective |
| **Domains**    | storage, cost, efficiency                                                                                             |
| **Confidence** | high                                                                                                                  |

## Supabase-Specific Rules

### rls_policy_columns_unindexed

| Property       | Value |
|----------------|-------|
| **Inputs**     | `rls_policy_column_indexing` |
| **Logic**      | high if > 5 tables with unindexed RLS columns; medium if > 2; low if any |
| **Domains**    | performance, efficiency |
| **Confidence** | high |

This is possibly the single highest-impact Supabase-specific finding. RLS is enabled by default on all Supabase tables exposed through PostgREST. Missing indexes on columns referenced in USING clauses cause sequential scans on every API request through that table.

### replication_slot_inactive_or_lagging

| Property       | Value |
|----------------|-------|
| **Inputs**     | `realtime_replication_slot_health` |
| **Logic**      | critical if inactive slot with lag > 1GB; high if lag > 500MB or inactive > 1 hour; medium if lag > 100MB |
| **Domains**    | availability, storage |
| **Confidence** | high |

### auth_table_bloat_detected

| Property       | Value |
|----------------|-------|
| **Inputs**     | `auth_schema_health` |
| **Logic**      | high if auth.sessions or auth.refresh_tokens dead_tuple_pct > 30% or row count > 5M with stale vacuum; medium if dead_tuple_pct > 10% or row count > 1M |
| **Domains**    | storage, performance, availability |
| **Confidence** | high |

### storage_soft_delete_pressure

| Property       | Value |
|----------------|-------|
| **Inputs**     | `storage_objects_health` |
| **Logic**      | high if soft_deleted_ratio > 20% and table size > 1GB; medium if soft_deleted_ratio > 10% |
| **Domains**    | storage, cost |
| **Confidence** | medium |

### system_schema_vacuum_stale

| Property       | Value |
|----------------|-------|
| **Inputs**     | `system_schema_bloat` |
| **Logic**      | high if any system table > 1M rows with no autovacuum in 7 days or dead_tuple_pct > 30%; medium if dead_tuple_pct > 10% |
| **Domains**    | storage, performance, operational_hygiene |
| **Confidence** | high |

### pool_mode_misconfiguration

| Property       | Value |
|----------------|-------|
| **Inputs**     | `pgbouncer_pool_health` |
| **Logic**      | medium if pool_mode = transaction AND application shows signs of prepared statement overhead (high planning time relative to execution time); low as informational if transaction mode detected |
| **Domains**    | performance, concurrency |
| **Confidence** | medium |

## Rule Attributes

Every rule should carry:

- **Workload context** — which profiles it applies to, whether severity varies by workload type
- **Confidence** — how trustworthy the inference is from available evidence
- **Prerequisites** — which probes must have succeeded
- **Whether history is required** — flag for future trend-based evolution

## What Rules Are Not

Rules produce **localized, mechanical insights** (findings). They are not the full interpretation layer.

Full interpretation also includes:
- Prioritization across findings
- Persona-aware framing
- Objective-aware weighting
- Cross-signal synthesis
- Narrative generation

That higher-order layer sits above the rule engine, typically in the reporting and review steps.
