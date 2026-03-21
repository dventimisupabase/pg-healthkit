# Probe System

## Purpose

Collect raw evidence from PostgreSQL. Probes are the instruments of the assessment system — they gather data. They do not interpret, score, or recommend.

## Probe Classification

| Class          | Description                                                    | When to Run                             |
|----------------|----------------------------------------------------------------|-----------------------------------------|
| **Baseline**   | Should run almost always                                       | Every assessment                        |
| **Contextual** | Useful when profile or symptoms justify                        | Based on profile, workload, or symptoms |
| **Optional**   | Available if privileges, extensions, or platform signals exist | When prerequisites are met              |

## Probe Model

Each probe defines:

| Property               | Description                                           |
|------------------------|-------------------------------------------------------|
| `name`                 | Stable identifier (e.g., `long_running_transactions`) |
| `purpose`              | What evidence this probe gathers                      |
| `prerequisites`        | Required extensions, privileges, or capabilities      |
| `execution_scope`      | database, platform, or both                           |
| `sql_file`             | Path to the SQL file                                  |
| `payload_shape`        | Canonical JSON structure of normalized output         |
| `candidate_findings`   | Which findings this probe can support                 |
| `affected_domains`     | Which score domains this probe feeds                  |
| `interpretation_notes` | Caveats, workload sensitivity, confidence guidance    |
| `profiles`             | Which assessment profiles include this probe          |
| `category`             | baseline, contextual, or optional                     |

See `probe_registry.yaml` for the machine-readable contracts.

## V1 Probe Inventory

### Baseline Probes (always run)

| #  | Probe                       | Purpose                                                                | Key Insight                                                                                    |
|----|-----------------------------|------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| 1  | `instance_metadata`         | Establish technical context                                            | Rarely generates severe findings alone; provides context for other probes                      |
| 2  | `extensions_inventory`      | Detect available capabilities and operational risks                    | Missing pg_stat_statements is important because it lowers diagnostic quality                   |
| 3  | `database_activity`         | Capture database-wide workload and pressure signals                    | Cumulative; depends on stats reset horizon                                                     |
| 4  | `connection_pressure`       | Understand connection management risk                                  | High idle count is not bad if pooler is present; high idle-in-transaction is almost always bad |
| 5  | `long_running_transactions` | Detect transaction behavior that harms vacuum, contention, reliability | One of the best v1 probes. High signal, low ambiguity                                          |
| 6  | `lock_blocking_chains`      | Detect active blocking and lock contention                             | Very strong probe. Absence at sample time is not evidence of absence                           |

### Baseline Probes (require pg_stat_statements)

| #  | Probe                      | Purpose                                              | Key Insight                                                                       |
|----|----------------------------|------------------------------------------------------|-----------------------------------------------------------------------------------|
| 7  | `top_queries_total_time`   | Identify queries consuming most total execution time | Leverage probe — feeds recommendations more than health severity                  |
| 8  | `top_queries_mean_latency` | Identify slow queries per-call                       | Interpret in context; slow means different things in OLTP vs OLAP                 |
| 9  | `temp_spill_queries`       | Detect queries spilling to temp files                | Lower confidence for global config recommendations unless repeated across queries |

### Baseline Probes (storage and maintenance)

| #  | Probe                       | Purpose                                                                | Key Insight                                                                                    |
|----|-----------------------------|------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| 10 | `largest_tables`            | Identify storage concentration and maintenance hotspots                | Often a context probe feeding other findings                                                   |
| 11 | `dead_tuple_ratio`          | Detect vacuum lag and bloat pressure                                   | Strong, especially paired with long transactions or stale maintenance                          |
| 12 | `stale_maintenance`         | Detect inadequate vacuum/analyze coverage                              | Null timestamps on tiny/cold tables may be harmless; weight by size and activity               |
| 13 | `unused_indexes`            | Detect write/storage waste                                             | Explicitly medium-confidence unless stats age is known                                         |

### Baseline Probes (security and hygiene)

| #  | Probe              | Purpose                                          | Key Insight                                                                             |
|----|--------------------|--------------------------------------------------|-----------------------------------------------------------------------------------------|
| 14 | `role_inventory`   | Detect superuser sprawl, unused roles, and risky role configurations | High signal for security hygiene; superuser count should be minimal |

### Contextual Probes

| #  | Probe                   | Purpose                                          | Key Insight                                                                          |
|----|-------------------------|--------------------------------------------------|--------------------------------------------------------------------------------------|
| 15 | `replication_health`    | Assess lag and replica posture                   | Severity depends on workload and whether replicas serve reads                        |
| 16 | `wal_checkpoint_health` | Assess checkpoint and background writer pressure | Less directly actionable than transaction/locking probes; improves operational depth |

## Probe-to-Finding Mapping

| Probe                       | Supports (primary)                                                            | Supports (corroboration)                                                                       |
|-----------------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| `instance_metadata`         | —                                                                             | `high_connection_utilization`, `checkpoint_pressure_detected`, `diagnostic_visibility_limited` |
| `extensions_inventory`      | `diagnostic_visibility_limited`                                               | —                                                                                              |
| `database_activity`         | `deadlocks_observed`                                                          | `significant_temp_spill_activity`, `checkpoint_pressure_detected`                              |
| `connection_pressure`       | `high_connection_utilization`, `idle_in_transaction_sessions_detected`        | —                                                                                              |
| `long_running_transactions` | `long_running_transactions_detected`, `idle_in_transaction_sessions_detected` | `dead_tuple_accumulation_detected`                                                             |
| `lock_blocking_chains`      | `active_lock_blocking_detected`                                               | `high_latency_queries_detected`                                                                |
| `top_queries_total_time`    | `high_impact_query_total_time`                                                | `significant_temp_spill_activity`                                                              |
| `top_queries_mean_latency`  | `high_latency_queries_detected`                                               | —                                                                                              |
| `temp_spill_queries`        | `significant_temp_spill_activity`                                             | `high_latency_queries_detected`                                                                |
| `largest_tables`            | `storage_concentration_risk`                                                  | `dead_tuple_accumulation_detected`, `potentially_unused_large_indexes`                         |
| `dead_tuple_ratio`          | `dead_tuple_accumulation_detected`                                            | `stale_vacuum_or_analyze_detected`                                                             |
| `stale_maintenance`         | `stale_vacuum_or_analyze_detected`                                            | `dead_tuple_accumulation_detected`                                                             |
| `unused_indexes`            | `potentially_unused_large_indexes`                                            | —                                                                                              |
| `replication_health`        | `replication_lag_elevated`                                                    | —                                                                                              |
| `role_inventory`            | `excessive_superuser_roles`                                                   | —                                                                                              |
| `wal_checkpoint_health`     | `checkpoint_pressure_detected`                                                | —                                                                                              |

## Probe-to-Score-Domain Mapping

### Availability
- **Primary:** `replication_health`, `long_running_transactions`, `lock_blocking_chains`, `wal_checkpoint_health`, `instance_metadata`
- **Secondary:** `database_activity`, `connection_pressure`

### Performance
- **Primary:** `top_queries_total_time`, `top_queries_mean_latency`, `temp_spill_queries`, `lock_blocking_chains`, `database_activity`
- **Secondary:** `dead_tuple_ratio`, `stale_maintenance`, `wal_checkpoint_health`

### Concurrency
- **Primary:** `connection_pressure`, `long_running_transactions`, `lock_blocking_chains`
- **Secondary:** `database_activity`, `top_queries_mean_latency`

### Storage
- **Primary:** `largest_tables`, `dead_tuple_ratio`, `stale_maintenance`, `unused_indexes`
- **Secondary:** `long_running_transactions`

### Efficiency
- **Primary:** `top_queries_total_time`, `temp_spill_queries`, `unused_indexes`, `wal_checkpoint_health`
- **Secondary:** `instance_metadata`, `largest_tables`

### Cost
- **Primary:** `largest_tables`, `unused_indexes`, `top_queries_total_time`, `temp_spill_queries`, `wal_checkpoint_health`
- **Secondary:** `instance_metadata`, `replication_health`

### Operational Hygiene
- **Primary:** `extensions_inventory`, `stale_maintenance`, `instance_metadata`, `role_inventory`
- **Secondary:** `database_activity`

## Probe Prerequisites

| Probe                       | Requires Extension | Requires Special Privilege | Notes                 |
|-----------------------------|--------------------|----------------------------|-----------------------|
| `instance_metadata`         | No                 | No                         | baseline              |
| `extensions_inventory`      | No                 | No                         | baseline              |
| `database_activity`         | No                 | Usually no                 | baseline              |
| `connection_pressure`       | No                 | May depend on visibility   | baseline              |
| `long_running_transactions` | No                 | May depend on visibility   | baseline              |
| `lock_blocking_chains`      | No                 | May depend on visibility   | baseline              |
| `top_queries_total_time`    | pg_stat_statements | Yes (to read view)         | baseline if available |
| `top_queries_mean_latency`  | pg_stat_statements | Same                       | baseline if available |
| `temp_spill_queries`        | pg_stat_statements | Same                       | baseline if available |
| `largest_tables`            | No                 | No                         | baseline              |
| `dead_tuple_ratio`          | No                 | No                         | baseline              |
| `stale_maintenance`         | No                 | No                         | baseline              |
| `unused_indexes`            | No                 | No                         | baseline              |
| `replication_health`        | No                 | Depends on primary/replica | contextual            |
| `role_inventory`            | No                 | No                         | baseline              |
| `wal_checkpoint_health`     | No                 | No                         | baseline              |

For Supabase, many privilege questions are controlled by platform posture, but the planner should still know when a probe is unavailable.

## Probe Profiles

### `default`
All baseline probes, plus pg_stat_statements probes if available, plus replication probe if relevant.

> **Design note:** The original methodology proposed separate `oltp_default` and `olap_default` profiles. These were consolidated into a single `default` profile for v1 simplicity. The workload-type distinction is instead handled at the rule evaluation layer, where conditions reference `assessment_context.workload_type` to adjust severity thresholds. If profile-level probe selection needs to differ between OLTP and OLAP (e.g., skipping certain probes for analytics workloads), consider splitting `default` into `oltp_default` and `olap_default` in a future version.

### `performance`
Emphasize: `top_queries_total_time`, `top_queries_mean_latency`, `temp_spill_queries`, `lock_blocking_chains`, `connection_pressure`, `dead_tuple_ratio`, `stale_maintenance`

### `reliability`
Emphasize: `replication_health`, `long_running_transactions`, `lock_blocking_chains`, `connection_pressure`, `wal_checkpoint_health`, `dead_tuple_ratio`

### `cost_capacity`
Emphasize: `largest_tables`, `unused_indexes`, `top_queries_total_time`, `temp_spill_queries`, `wal_checkpoint_health`, `replication_health`

## Implementation Prioritization

### First Wave (highest value, fewest dependencies)
1. `instance_metadata`
2. `extensions_inventory`
3. `connection_pressure`
4. `long_running_transactions`
5. `lock_blocking_chains`
6. `largest_tables`
7. `dead_tuple_ratio`
8. `stale_maintenance`
9. `role_inventory`

### Second Wave (requires pg_stat_statements)
10. `database_activity`
11. `top_queries_total_time`
12. `top_queries_mean_latency`
13. `temp_spill_queries`

### Third Wave (more operational depth)
14. `replication_health`
15. `wal_checkpoint_health`
16. `unused_indexes`

## Optional v1.1 Probes

Good but not required for a credible first release:
- `duplicate_indexes` — Heuristic detection of duplicate or overlapping indexes (indexes on the same table sharing the same leading key columns). These represent write amplification and storage waste. Mark as low-confidence since overlap does not always mean redundancy.
- `table_growth_proxy` — Snapshot of current table sizes for growth rate estimation. Important caveat: true growth rate is unavailable from a single snapshot. Do not pretend otherwise. At best, report current size and recommend repeat sampling for trend detection.
- `bloat_estimate` — Approximate table bloat from catalog statistics. The underlying query is inherently low-confidence; prefer `pgstattuple` extension when available. Mark findings as low-confidence.
- `sequential_scan_heavy_tables` — Tables with high sequential scan counts relative to index scans. For OLTP this is often a useful smell, not automatically a bug. Context-dependent.
- `vacuum_progress`
- `analyze_progress`
- `cache_hit_ratio`
- `table_xid_age`
- `prepared_transactions`
- `replica_conflicts`

## Supabase-Specific Probes

### Critical (v1)

#### 17. rls_policy_column_indexing

**Purpose:** Detect missing indexes on columns used in RLS USING clauses.
**Prerequisites:** None.
**Execution scope:** database.
**Collects:** For each table with RLS enabled, extract columns referenced in USING/WITH CHECK clauses, check if those columns have indexes.
**Candidate findings:** `rls_policy_columns_unindexed`.
**Affected domains:** performance, efficiency.
**Interpretation:** RLS is enabled by default in Supabase. Missing indexes on RLS filter columns cause sequential scans on every query through that table. This is arguably the #1 Supabase-specific performance issue. High signal, high confidence.

#### 18. realtime_replication_slot_health

**Purpose:** Detect unconsumed or lagging logical replication slots used by Supabase Realtime.
**Prerequisites:** Realtime enabled.
**Execution scope:** database.
**Collects:** slot_name, slot_type, active, xmin, confirmed_flush_lsn, current WAL LSN, lag_bytes (computed).
**Candidate findings:** `replication_slot_lag_elevated` (Supabase-specific variant), `replication_slot_inactive`.
**Affected domains:** availability, storage.
**Interpretation:** Supabase Realtime uses logical replication. Unconsumed or inactive slots prevent WAL cleanup and can fill disk. This is a common cause of disk pressure incidents.

#### 19. auth_schema_health

**Purpose:** Detect bloat and vacuum lag on Supabase Auth tables.
**Prerequisites:** auth schema exists.
**Execution scope:** database.
**Collects:** For auth.users, auth.sessions, auth.refresh_tokens, auth.mfa_factors: row counts, dead tuple counts, dead tuple percentage, last autovacuum, last autoanalyze, table size.
**Candidate findings:** `auth_table_bloat_detected`, `auth_session_explosion`.
**Affected domains:** storage, performance, availability.
**Interpretation:** Auth tables experience high churn (especially sessions and refresh_tokens). Stale vacuum on these tables slows login flows and bloats storage. Weight by whether Supabase Auth is the active auth provider.

#### 20. storage_objects_health

**Purpose:** Detect growth pressure and cleanup lag on storage.objects.
**Prerequisites:** storage schema exists.
**Execution scope:** database.
**Collects:** storage.objects row count, soft-deleted row count (where deleted_at IS NOT NULL), total table size, dead tuples, last autovacuum.
**Candidate findings:** `storage_soft_delete_pressure`, `storage_objects_bloat`.
**Affected domains:** storage, cost.
**Interpretation:** storage.objects can grow very large in file-heavy applications. Soft-deleted rows that aren't cleaned up waste storage and slow queries against the table.

#### 21. system_schema_bloat

**Purpose:** Detect vacuum/maintenance pressure across all Supabase system schemas.
**Prerequisites:** None.
**Execution scope:** database.
**Collects:** For tables in auth, storage, realtime, extensions, supabase_functions schemas: schema, table, n_live_tup, n_dead_tup, dead_tuple_pct, last_autovacuum, last_autoanalyze, pg_total_relation_size.
**Candidate findings:** `system_schema_vacuum_stale`.
**Affected domains:** storage, performance, operational_hygiene.
**Interpretation:** System schemas are managed by the platform but still need vacuum like any other tables. Customers often don't monitor these because they "belong to Supabase." High dead tuple ratios on system tables indicate platform-level maintenance gaps.

#### 22. pgbouncer_pool_health

**Purpose:** Detect connection pool mode and contention.
**Prerequisites:** PgBouncer/Supavisor metrics accessible.
**Execution scope:** platform.
**Collects:** pool_mode (transaction/session), active connections, idle connections, waiting clients, max pool size.
**Candidate findings:** `pool_mode_misconfiguration`, `pool_contention_detected`.
**Affected domains:** concurrency, performance.
**Interpretation:** Transaction mode breaks prepared statement caching (causing repeated planning overhead). Session mode limits connection reuse. High waiting client count indicates pool undersizing.

> **Note on Platform Scope:** Probes with `platform` execution scope may require access to platform-specific APIs (e.g., Supabase Management API) or metrics endpoints in addition to a standard database connection.

### Contextual (v1.1)

#### 23. pg_cron_job_health

**Purpose:** Detect failed or long-running scheduled jobs.
**Prerequisites:** pg_cron extension.
**Execution scope:** database.
**Collects:** job name, schedule, last run time, last duration, last status, error messages from cron.job_run_details.
**Candidate findings:** `pg_cron_job_failures`.
**Affected domains:** availability, operational_hygiene.
**Interpretation:** Failed cron jobs may indicate schema issues, permission problems, or resource contention. Long-running jobs can spike CPU/lock pressure during execution windows.

#### 24. extension_version_health

**Purpose:** Detect outdated or potentially incompatible extensions.
**Prerequisites:** None.
**Execution scope:** database.
**Collects:** installed extension names and versions, available (upgradeable) versions from pg_available_extension_versions.
**Candidate findings:** `extension_version_outdated`.
**Affected domains:** operational_hygiene, availability.
**Interpretation:** Outdated extensions may miss security patches or performance improvements. On Supabase, extension upgrades are sometimes tied to platform version upgrades.

#### 25. pgvector_index_health

**Purpose:** Assess vector index configuration and health.
**Prerequisites:** pgvector extension.
**Execution scope:** database.
**Collects:** vector indexes (HNSW/IVFFlat), index size, table row count, index parameters (m, ef_construction for HNSW; lists for IVFFlat), tables with vector columns but no vector index.
**Candidate findings:** `pgvector_missing_index`, `pgvector_index_misconfigured`.
**Affected domains:** performance, efficiency.
**Interpretation:** Missing vector indexes cause sequential distance scans. HNSW with default parameters may not suit the dataset size. IVFFlat with too few lists reduces recall.

### Supabase Probe-to-Finding Mapping

| Probe                              | Supports (primary)                                       | Supports (corroboration)                |
|------------------------------------|----------------------------------------------------------|-----------------------------------------|
| `rls_policy_column_indexing`       | `rls_policy_columns_unindexed`                           | —                                       |
| `realtime_replication_slot_health` | `replication_slot_inactive_or_lagging`                   | `wal_checkpoint_health`                 |
| `auth_schema_health`               | `auth_table_bloat_detected`, `auth_session_explosion`    | `dead_tuple_ratio`, `stale_maintenance` |
| `storage_objects_health`           | `storage_soft_delete_pressure`, `storage_objects_bloat`  | `largest_tables`                        |
| `system_schema_bloat`              | `system_schema_vacuum_stale`                             | `stale_maintenance`                     |
| `pgbouncer_pool_health`            | `pool_mode_misconfiguration`, `pool_contention_detected` | `top_queries_total_time`                |
| `pg_cron_job_health`               | `pg_cron_job_failures`                                   | —                                       |
| `extension_version_health`         | `extension_version_outdated`                             | `extensions_inventory`                  |
| `pgvector_index_health`            | `pgvector_missing_index`, `pgvector_index_misconfigured` | `largest_tables`                        |

### Supabase Probe-to-Score-Domain Mapping (additions)

#### Availability
- **Primary:** `realtime_replication_slot_health`, `auth_schema_health`
- **Secondary:** `pg_cron_job_health`, `extension_version_health`

#### Performance
- **Primary:** `rls_policy_column_indexing`, `pgbouncer_pool_health`, `pgvector_index_health`
- **Secondary:** `auth_schema_health`, `system_schema_bloat`

#### Concurrency
- **Primary:** `pgbouncer_pool_health`

#### Storage
- **Primary:** `realtime_replication_slot_health`, `auth_schema_health`, `storage_objects_health`, `system_schema_bloat`

#### Efficiency
- **Primary:** `rls_policy_column_indexing`, `pgvector_index_health`

#### Cost
- **Primary:** `storage_objects_health`
- **Secondary:** `system_schema_bloat`

#### Operational Hygiene
- **Primary:** `system_schema_bloat`, `pg_cron_job_health`, `extension_version_health`

## Stats Reset Horizon

Many probes collect cumulative statistics from views like `pg_stat_database`, `pg_stat_user_tables`, and `pg_stat_statements`. These counters accumulate since the last statistics reset (via `pg_stat_reset()` or server restart). Without knowing the stats age, cumulative values are uninterpretable — 50 deadlocks over 1 hour is very different from 50 deadlocks over 6 months.

This is a system-wide principle, not specific to any single probe:

- **Probes that collect cumulative stats should record the stats reset timestamp** (from `pg_stat_database.stats_reset`) in their metadata when available
- **The normalizer should propagate stats age** into the canonical payload metadata so rules can assess whether cumulative values are meaningful
- **Rules should not assign high severity to cumulative thresholds** without evidence of the observation window — a cumulative deadlock count of 5 with an unknown stats window should be flagged at lower confidence than the same count over a known 24-hour window
- **Reports should disclose the stats observation window** when presenting cumulative evidence

## Standardized Evidence Payload

All probe evidence uses a common wrapper. See `normalizer_interface_contract.md` for the full specification.

```json
{
  "probe_name": "long_running_transactions",
  "probe_version": "2026-03-20",
  "collected_at": "2026-03-20T20:15:00Z",
  "status": "success",
  "summary": { ... },
  "rows": [ ... ],
  "metadata": {
    "duration_ms": 14,
    "collector_version": "0.1.0",
    "database_name": "postgres"
  }
}
```

## Probe Registry

Each probe has a declarative registry entry. See `probe_registry.yaml` for the full v1 registry.

Example entry:

```yaml
name: long_running_transactions
version: 2026-03-20
enabled_by_default: true
profiles:
  - default
  - performance
  - reliability
requires:
  extensions: []
  capabilities: []
sql_file: probes/long_running_transactions.sql
supports_findings:
  - long_running_transactions_detected
  - idle_in_transaction_sessions_detected
affects_domains:
  - concurrency
  - storage
  - availability
confidence: high
```
