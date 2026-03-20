# V1 Probe Catalog

This document provides the human-readable probe catalog with purpose, interpretation guidance, and inter-probe relationships. For machine-readable payload contracts, see `probe_registry.yaml`.

## 1. instance_metadata

**Purpose:** Establish technical context for the rest of the assessment.

**Collects:** PostgreSQL version, recovery state, max_connections, shared_buffers, work_mem, maintenance_work_mem, effective_cache_size, max_wal_size, checkpoint_timeout, autovacuum enabled.

**Interpretation:** This is mostly contextual evidence. It should rarely generate a severe finding by itself unless a configuration is clearly pathological (e.g., autovacuum disabled, max_connections set to 10000).

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

## 14. replication_health

**Purpose:** Assess lag and replica posture.

**Collects (primary):** application_name, replica state, sync state, write/flush/replay lag.
**Collects (replica):** replay delay, in_recovery flag.

**Interpretation:** Severity depends heavily on workload and whether replicas serve reads. Async replication with moderate lag may be fine if replicas are only for failover.

## 15. wal_checkpoint_health

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
| `storage_concentration_risk`            | `largest_tables`                                   | `unused_indexes`                              |

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
