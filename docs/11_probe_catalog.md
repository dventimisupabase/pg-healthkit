# V1 Probe Catalog

This document provides the human-readable probe catalog with purpose, interpretation guidance, and inter-probe relationships. For machine-readable payload contracts, see `probe_registry.yaml`.

## 1. instance_metadata

**Purpose:** Establish technical context for the rest of the assessment.

**Collects:** PostgreSQL version, recovery state, max_connections, shared_buffers, work_mem, maintenance_work_mem, effective_cache_size, max_wal_size, checkpoint_timeout, autovacuum enabled, random_page_cost, log_min_duration_statement, track_io_timing, shared_preload_libraries.

**Interpretation:** This is mostly contextual evidence. It should rarely generate a severe finding by itself unless a configuration is clearly pathological (e.g., autovacuum disabled, max_connections set to 10000). However, `track_io_timing = off` means I/O timing data is unavailable for diagnostics, `log_min_duration_statement = -1` means slow query logging is disabled, and `random_page_cost = 4.0` on SSD storage causes the planner to over-prefer sequential scans. These are diagnostic quality signals that feed the `diagnostic_configuration_weak` finding.

## 2. extensions_inventory

**Purpose:** Detect available capability and potential operational risks.

**Collects:** Installed extensions and their versions.

**Interpretation:** Missing `pg_stat_statements` is important because it lowers diagnostic quality for the entire assessment, but it is not a direct performance defect. It is a meta-finding about observability.

## 3. database_activity

**Purpose:** Capture database-wide workload and pressure signals.

**Collects:** Commits, rollbacks, blocks hit/read, tuples returned/fetched/inserted/updated/deleted, temp files/bytes, deadlocks, block read/write time.

**Interpretation:** This is cumulative data that depends on stats reset horizon. Metadata should record stats age if possible. Deadlocks > 0 is always worth flagging. High temp_bytes is a spill signal.

## 4. connection_pressure

**Purpose:** Understand whether connection management is a risk.

**Collects:** Total sessions, active/idle/idle-in-transaction counts, connection utilization ratio vs max_connections.

**Interpretation:** High idle count is not inherently bad if a pooler is present, but high idle-in-transaction is almost always bad. Utilization above 80% is a warning; above 90% is high risk.

## 5. long_running_transactions

**Purpose:** Detect transaction behavior that harms vacuum, contention, and reliability.

**Collects:** Oldest transactions with age, query age, state, wait events, application name, user, client.

**Interpretation:** One of the best v1 probes. High signal, low ambiguity. Transactions older than 1 hour are almost always problematic. Idle-in-transaction state is an aggravating factor.

## 6. lock_blocking_chains

**Purpose:** Detect active blocking and lock contention.

**Collects:** Blocked/blocker PIDs, queries, wait events, application names, users.

**Interpretation:** Another very strong v1 probe. If nothing is blocked at sample time, absence of evidence is not evidence of absence. Consider recommending periodic sampling.

## 7. top_queries_total_time

**Purpose:** Identify the queries consuming the most total execution time.

**Requires:** `pg_stat_statements`

**Collects:** queryid, calls, total_exec_time, mean_exec_time, rows, shared blocks hit/read, temp blocks, query text.

**Interpretation:** This is a leverage probe, not always a "finding" probe. It often feeds recommendations more than health severity. The top total-time query is the best optimization leverage point.

## 8. top_queries_mean_latency

**Purpose:** Identify slow queries on a per-call basis.

**Requires:** `pg_stat_statements`

**Collects:** queryid, calls, mean_exec_time, max_exec_time, stddev_exec_time, rows, query text.

**Interpretation:** Interpret in context. In OLAP, a slow query means something different than in OLTP. High stddev indicates unstable latency, which may matter even when mean is acceptable.

## 9. temp_spill_queries

**Purpose:** Detect queries spilling to temp files due to sort/hash pressure or plan shape.

**Requires:** `pg_stat_statements`

**Collects:** queryid, calls, temp_blks_read, temp_blks_written, total_exec_time, mean_exec_time, query text.

**Interpretation:** Very useful for performance work. Lower confidence for global configuration recommendations (e.g., raising work_mem) unless repeated across multiple queries. Better to fix query/index issues first.

## 10. largest_tables

**Purpose:** Identify storage concentration and likely maintenance hotspots.

**Collects:** Schema, table, total size, heap size, index size, live tuples, dead tuples.

**Interpretation:** Often a context probe feeding other findings. Tells you where to focus cost, maintenance, and bloat analysis.

## 11. dead_tuple_ratio

**Purpose:** Detect likely vacuum lag and bloat pressure.

**Collects:** Live tuples, dead tuples, dead tuple percentage, last vacuum/autovacuum, last analyze/autoanalyze.

**Interpretation:** Strong probe, especially when paired with long transactions or stale maintenance. High dead tuple percentage on large active tables is a clear signal.

## 12. stale_maintenance

**Purpose:** Detect tables not being vacuumed/analyzed adequately.

**Collects:** Last autovacuum, last autoanalyze, operation counts, relation size proxy.

**Interpretation:** Null timestamps on tiny or cold tables may be harmless. Weight by size and activity. Large tables (> 1M tuples) with no autoanalyze are a concern.

## 13. unused_indexes

**Purpose:** Detect likely write/storage waste from unused indexes.

**Collects:** Schema, table, index name, idx_scan count, index size.

**Interpretation:** This is explicitly medium-confidence unless stats age is known and representative. Never recommend dropping indexes based solely on a short observation window.

## 14. role_inventory

**Purpose:** Detect superuser sprawl, unused roles, and risky role configurations.

**Collects:** Role name, superuser flag, create-role flag, create-db flag, replication flag, login flag, password expiry (VALID UNTIL).

**Interpretation:** Superuser roles bypass all permission checks including RLS. More than one superuser role (beyond the default `postgres`) is a security hygiene concern. Roles with `LOGIN` + `SUPERUSER` + no `VALID UNTIL` are highest risk. Unused roles (exist but never connect) should be flagged for cleanup.

## 15. replication_health

**Purpose:** Assess lag and replica posture.

**Collects (primary):** application_name, replica state, sync state, write/flush/replay lag.
**Collects (replica):** replay delay, in_recovery flag.

**Interpretation:** Severity depends heavily on workload and whether replicas serve reads. Async replication with moderate lag may be fine if replicas are only for failover.

## 16. wal_checkpoint_health

**Purpose:** Assess checkpoint and background writer pressure.

**Collects:** Checkpoints timed/requested, checkpoint write/sync time, buffers checkpoint/clean/backend, buffers_backend_fsync. Optionally WAL stats (newer PG versions).

**Interpretation:** Useful but less directly actionable than transaction/locking/query probes. Keep it in v1 because it improves operational depth. High buffers_backend means backends are doing their own writes — checkpoint tuning may be off.

## Probe-to-Finding Mapping Matrix

| Finding                                 | Primary Probes                                     | Corroborating Probes                          |
|-----------------------------------------|----------------------------------------------------|-----------------------------------------------|
| `long_running_transactions_detected`    | `long_running_transactions`                        | —                                             |
| `idle_in_transaction_sessions_detected` | `connection_pressure`, `long_running_transactions` | —                                             |
| `active_lock_blocking_detected`         | `lock_blocking_chains`                             | —                                             |
| `deadlocks_observed`                    | `database_activity`                                | —                                             |
| `high_connection_utilization`           | `connection_pressure`                              | `instance_metadata`                           |
| `significant_temp_spill_activity`       | `temp_spill_queries`                               | `database_activity`, `top_queries_total_time` |
| `high_impact_query_total_time`          | `top_queries_total_time`                           | —                                             |
| `high_latency_queries_detected`         | `top_queries_mean_latency`                         | `temp_spill_queries`, `lock_blocking_chains`  |
| `dead_tuple_accumulation_detected`      | `dead_tuple_ratio`                                 | `long_running_transactions`, `largest_tables` |
| `stale_vacuum_or_analyze_detected`      | `stale_maintenance`                                | `dead_tuple_ratio`                            |
| `potentially_unused_large_indexes`      | `unused_indexes`                                   | `largest_tables`                              |
| `replication_lag_elevated`              | `replication_health`                               | —                                             |
| `checkpoint_pressure_detected`          | `wal_checkpoint_health`                            | `database_activity`, `instance_metadata`      |
| `diagnostic_visibility_limited`         | `extensions_inventory`                             | —                                             |
| `diagnostic_configuration_weak`         | `instance_metadata`                                | —                                             |
| `storage_concentration_risk`            | `largest_tables`                                   | `unused_indexes`                              |
| `excessive_superuser_roles`             | `role_inventory`                                   | —                                             |

## Strongest Probes for Immediate Value

1. `long_running_transactions`
2. `lock_blocking_chains`
3. `connection_pressure`
4. `top_queries_total_time`
5. `top_queries_mean_latency`
6. `dead_tuple_ratio`
7. `stale_maintenance`
8. `replication_health`

## Best Score Coverage with Least Complexity

| Domain            | Key Probes                                                         |
|-------------------|--------------------------------------------------------------------|
| Availability      | replication, long xacts, blocking                                  |
| Performance       | top queries, temp spill, blocking, dead tuples                     |
| Concurrency       | connections, long xacts, blocking                                  |
| Storage           | dead tuples, maintenance, large tables, unused indexes             |
| Cost / Efficiency | top queries, temp spill, large tables, unused indexes, checkpoints |

## Optional v1.1 Probes

### duplicate_indexes

**Purpose:** Heuristic detection of duplicate or overlapping indexes on the same table.

**Collects:** Table name, index name, index definition for indexes that share the same table and leading key columns.

**Interpretation:** This is heuristic only. Overlapping indexes are not always redundant — a covering index may serve different queries than its prefix subset. However, true duplicates represent pure write amplification and storage waste. Mark findings as low-confidence and recommend manual review before dropping. The SQL groups by `indrelid` and `indkey` and flags tables with multiple indexes sharing the same key definition.

**Candidate findings:** `duplicate_or_overlapping_indexes`

**Affected domains:** storage, efficiency, cost

### table_growth_proxy

**Purpose:** Snapshot current table sizes for growth rate estimation via repeat sampling.

**Collects:** Schema, table, total relation size in bytes.

**Interpretation:** If you do not have historical telemetry, true growth rate is unavailable from one snapshot. That is important. Do not pretend otherwise. At best, report current size and recommend repeat sampling. This probe becomes valuable in Phase 3 (time-series aware) when diffing between assessment runs. In v1, it provides a size baseline for the `largest_tables` probe and informs cost/capacity discussions.

**Candidate findings:** None directly in v1 (context-only probe; becomes useful for trend findings in v1.1+)

**Affected domains:** cost, storage

### bloat_estimate

**Purpose:** Approximate table bloat from catalog statistics.

**Collects:** Schema, table, table size, estimated tuple size, approximate bloat bytes and percentage.

**Interpretation:** The underlying query is ugly and inherently low-confidence. It relies on `pg_stats` averages and may misestimate for tables with highly variable row widths. Prefer `pgstattuple` extension when available for accurate measurements. Always mark bloat findings as low-confidence when derived from this probe.

**Candidate findings:** `table_bloat_estimated`

**Affected domains:** storage, cost, performance

### sequential_scan_heavy_tables

**Purpose:** Detect tables with disproportionately high sequential scan counts.

**Collects:** Schema, table, seq_scan count, idx_scan count, seq-to-idx ratio, live tuple count.

**Interpretation:** For OLTP, high sequential scans on large tables are often a useful smell indicating missing indexes or poor filter selectivity. Not automatically a bug — small tables are expected to be seq-scanned, and OLAP workloads are inherently scan-heavy. Weight by table size and workload type.

**Candidate findings:** `sequential_scan_dominant`

**Affected domains:** performance, efficiency

### cache_hit_ratio

**Purpose:** Directional signal for buffer cache efficiency.

**Collects:** Database name, blocks hit, blocks read, cache hit percentage.

**Interpretation:** Use cautiously; this is a directional signal, not a health score by itself. A high cache hit ratio (> 99%) is normal for well-sized OLTP workloads. A low ratio may indicate working set exceeds shared_buffers, but it can also reflect a cold start, a recent stats reset, or an OLAP workload that naturally scans large datasets. Never use this as a standalone health metric — always interpret in context of workload type and I/O patterns.

**Candidate findings:** `low_cache_hit_ratio` (context-dependent, low confidence without corroborating signals)

**Affected domains:** performance, efficiency

### vacuum_progress

**Purpose:** Show currently running vacuum operations and their progress.

**Collects:** PID, relation, phase, heap blocks total/scanned/vacuumed, index vacuum count, max/current dead tuples.

**Interpretation:** This is a point-in-time snapshot of active vacuum operations. Useful for understanding whether vacuum is actively working on large tables and how far along it is. If no vacuums are running, the probe returns zero rows — that is normal and not a finding. Most valuable when paired with `dead_tuple_ratio` or `stale_maintenance` to understand *why* vacuum might not be keeping up.

**Candidate findings:** None directly (observational probe; useful for corroboration)

**Affected domains:** storage, performance

### analyze_progress

**Purpose:** Show currently running analyze operations and their progress.

**Collects:** PID, relation, phase, sample blocks total/scanned, extended stats total/computed.

**Interpretation:** Similar to vacuum_progress — a point-in-time snapshot. Zero rows is normal. Useful for understanding whether statistics gathering is active and potentially consuming resources during the assessment window.

**Candidate findings:** None directly (observational probe; useful for corroboration)

**Affected domains:** performance

### index_usage

**Purpose:** Show all index usage statistics ordered by scan frequency and size.

**Collects:** Schema, table, index name, idx_scan count, index size.

**Interpretation:** Complements the `unused_indexes` probe by showing the full index usage spectrum, not just zero-scan indexes. Low-scan large indexes are worth reviewing even if not strictly zero. Ordered by ascending scan count and descending size, so the most wasteful indexes appear first. Same stats-window caveats apply as with `unused_indexes`.

**Candidate findings:** `low_usage_large_indexes` (low confidence without representative stats window)

**Affected domains:** storage, efficiency, cost

### table_xid_age

**Purpose:** Detect tables approaching transaction ID wraparound risk.

**Collects:** Schema, table, xid age (via `age(relfrozenxid)`), total size, live tuples, last autovacuum, last vacuum.

**Interpretation:** Transaction ID wraparound is one of the few scenarios where PostgreSQL will refuse to accept new writes (emergency shutdown at 2^31 - 1M transactions). Tables with xid age approaching `autovacuum_freeze_max_age` (default 200M) trigger aggressive anti-wraparound vacuum. Tables above 500M xid age are a concern. Above 1B is high severity. This probe is especially important when long-running transactions prevent vacuum from advancing the freeze horizon.

**Candidate findings:** `xid_wraparound_risk`

**Affected domains:** availability, storage

### prepared_transactions

**Purpose:** Detect abandoned two-phase commit transactions.

**Collects:** Global ID (gid), prepared timestamp, owner, database, transaction age.

**Interpretation:** Prepared transactions (from `PREPARE TRANSACTION`) survive connection close and server restart. They hold locks and prevent vacuum progress just like long-running transactions, but are harder to discover. Any prepared transaction older than a few minutes is suspicious. Most applications do not use two-phase commit at all, so any rows returned from this probe are worth investigating. If `max_prepared_transactions = 0`, this probe should be skipped.

**Candidate findings:** `abandoned_prepared_transactions`

**Affected domains:** concurrency, storage, availability

### replica_conflicts

**Purpose:** Detect query cancellations and conflict events on streaming replicas.

**Collects:** Database name, conflict counts by type (tablespace, lock, snapshot, bufferpin, deadlock).

**Interpretation:** Conflicts occur when the primary's cleanup operations (vacuum, buffer cleanup) conflict with long-running queries on the replica. High `confl_snapshot` counts indicate that queries on the replica are being cancelled because the primary vacuumed away rows they need. This is the most common conflict type and is aggravated by long queries on replicas combined with aggressive vacuum on the primary. Only meaningful when `pg_is_in_recovery() = true`. Cumulative counters — interpret relative to stats age.

**Candidate findings:** `replica_conflict_rate_high`

**Affected domains:** availability, performance

## Supabase-Specific Probes

### 17. rls_policy_column_indexing

**Purpose:** Detect missing indexes on columns used in RLS USING clauses.

**Collects:** For each table with RLS enabled, columns referenced in USING/WITH CHECK clauses and whether those columns have indexes.

**Interpretation:** RLS is enabled by default in Supabase. Missing indexes on RLS filter columns cause sequential scans on every query through that table. This is arguably the #1 Supabase-specific performance issue. High signal, high confidence.

### 18. realtime_replication_slot_health

**Purpose:** Detect unconsumed or lagging logical replication slots used by Supabase Realtime.

**Requires:** Realtime enabled.

**Collects:** slot_name, slot_type, active, xmin, confirmed_flush_lsn, current WAL LSN, lag_bytes (computed).

**Interpretation:** Supabase Realtime uses logical replication. Unconsumed or inactive slots prevent WAL cleanup and can fill disk. This is a common cause of disk pressure incidents.

### 19. auth_schema_health

**Purpose:** Detect bloat and vacuum lag on Supabase Auth tables.

**Requires:** auth schema exists.

**Collects:** For auth.users, auth.sessions, auth.refresh_tokens, auth.mfa_factors: row counts, dead tuple counts, dead tuple percentage, last autovacuum, last autoanalyze, table size.

**Interpretation:** Auth tables experience high churn (especially sessions and refresh_tokens). Stale vacuum on these tables slows login flows and bloats storage. Weight by whether Supabase Auth is the active auth provider.

### 20. storage_objects_health

**Purpose:** Detect growth pressure and cleanup lag on storage.objects.

**Requires:** storage schema exists.

**Collects:** storage.objects row count, soft-deleted row count (where deleted_at IS NOT NULL), total table size, dead tuples, last autovacuum.

**Interpretation:** storage.objects can grow very large in file-heavy applications. Soft-deleted rows that aren't cleaned up waste storage and slow queries against the table.

### 21. system_schema_bloat

**Purpose:** Detect vacuum/maintenance pressure across all Supabase system schemas.

**Collects:** For tables in auth, storage, realtime, extensions, supabase_functions schemas: schema, table, n_live_tup, n_dead_tup, dead_tuple_pct, last_autovacuum, last_autoanalyze, pg_total_relation_size.

**Interpretation:** System schemas are managed by the platform but still need vacuum like any other tables. Customers often don't monitor these because they "belong to Supabase." High dead tuple ratios on system tables indicate platform-level maintenance gaps.

### 22. pgbouncer_pool_health

**Purpose:** Detect connection pool mode and contention.

**Requires:** PgBouncer/Supavisor metrics accessible.

**Collects:** pool_mode (transaction/session), active connections, idle connections, waiting clients, max pool size.

**Interpretation:** Transaction mode breaks prepared statement caching (causing repeated planning overhead). Session mode limits connection reuse. High waiting client count indicates pool undersizing.

### 23. pg_cron_job_health

**Purpose:** Detect failed or long-running scheduled jobs.

**Requires:** pg_cron extension.

**Collects:** job name, schedule, last run time, last duration, last status, error messages from cron.job_run_details.

**Interpretation:** Failed cron jobs may indicate schema issues, permission problems, or resource contention. Long-running jobs can spike CPU/lock pressure during execution windows.

### 24. extension_version_health

**Purpose:** Detect outdated or potentially incompatible extensions.

**Collects:** installed extension names and versions, available (upgradeable) versions from pg_available_extension_versions.

**Interpretation:** Outdated extensions may miss security patches or performance improvements. On Supabase, extension upgrades are sometimes tied to platform version upgrades.

### 25. pgvector_index_health

**Purpose:** Assess vector index configuration and health.

**Requires:** pgvector extension.

**Collects:** vector indexes (HNSW/IVFFlat), index size, table row count, index parameters (m, ef_construction for HNSW; lists for IVFFlat), tables with vector columns but no vector index.

**Interpretation:** Missing vector indexes cause sequential distance scans. HNSW with default parameters may not suit the dataset size. IVFFlat with too few lists reduces recall.

## Supabase Probe-to-Finding Mapping

| Finding                                | Primary Probes                     | Corroborating Probes                    |
|----------------------------------------|------------------------------------|-----------------------------------------|
| `rls_policy_columns_unindexed`         | `rls_policy_column_indexing`       | —                                       |
| `replication_slot_inactive_or_lagging` | `realtime_replication_slot_health` | `wal_checkpoint_health`                 |
| `auth_table_bloat_detected`            | `auth_schema_health`               | `dead_tuple_ratio`, `stale_maintenance` |
| `storage_soft_delete_pressure`         | `storage_objects_health`           | `largest_tables`                        |
| `system_schema_vacuum_stale`           | `system_schema_bloat`              | `stale_maintenance`                     |
| `pool_mode_misconfiguration`           | `pgbouncer_pool_health`            | `top_queries_total_time`                |
| `pg_cron_job_failures`                 | `pg_cron_job_health`               | —                                       |
| `extension_version_outdated`           | `extension_version_health`         | `extensions_inventory`                  |
| `pgvector_missing_index`               | `pgvector_index_health`            | `largest_tables`                        |
| `pgvector_index_misconfigured`         | `pgvector_index_health`            | —                                       |
| `pool_contention_detected`             | `pgbouncer_pool_health`            | `top_queries_total_time`                |
| `auth_session_explosion`               | `auth_schema_health`               | `largest_tables`                        |
| `storage_objects_bloat`                | `storage_objects_health`           | `dead_tuple_ratio`                      |
