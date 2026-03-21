# V1 Findings Catalog

This document defines the v1 findings with their logic, inputs, severity gradation, and domain effects. There are 17 generic findings and 13 Supabase-specific findings (30 total). For the machine-readable rule definitions, see `rules.yaml`.

## Finding Structure

Each finding includes:

| Field            | Purpose                                                                                     |
|------------------|---------------------------------------------------------------------------------------------|
| `finding_key`    | Stable identifier for the issue class                                                       |
| `domain`         | Primary health domain                                                                       |
| `severity`       | Operational/business importance (info → critical)                                           |
| `confidence`     | How trustworthy the inference is                                                            |
| `title`          | Human-readable title                                                                        |
| `summary`        | What was observed                                                                           |
| `cause`          | Likely root cause (not symptoms)                                                            |
| `impact`         | Why it matters                                                                              |
| `recommendation` | What to do, including tradeoffs (what could go wrong, what the recommendation costs)        |
| `urgency`        | Remediation timeframe: `immediate` (1 week), `short_term` (30 days), `structural` (quarter) |
| `evidence_refs`  | Links to supporting probe evidence                                                          |
| `tags`           | Classification labels                                                                       |

## Findings

### 1. long_running_transactions_detected

**Domain:** concurrency
**Inputs:** `long_running_transactions`

| Condition                                   | Severity | Confidence |
|---------------------------------------------|----------|------------|
| Oldest xact > 1 hour                        | high     | high       |
| Oldest xact > 15 minutes                    | medium   | high       |
| Oldest xact > 5 minutes AND workload = OLTP | low      | medium     |

Increase severity if state is `idle in transaction`.

**Cause:** Application transaction boundaries are too broad, or sessions are being abandoned without rollback.
**Impact:** Long-running transactions can block vacuum progress, increase table bloat, and amplify lock contention.
**Recommendation:** Review application transaction boundaries, identify abandoned sessions, and reduce the lifetime of interactive transactions.
**Urgency:** short_term
**Score effects (high):** concurrency -20, storage -10, availability -8

---

### 2. idle_in_transaction_sessions_detected

**Domain:** concurrency
**Inputs:** `connection_pressure`, `long_running_transactions`

| Condition                                         | Severity | Confidence |
|---------------------------------------------------|----------|------------|
| idle-in-transaction count ≥ 3 AND oldest > 15 min | high     | high       |
| idle-in-transaction count ≥ 1 AND oldest > 5 min  | medium   | high       |

**Cause:** Client applications are not closing transactions promptly, or connection pool configuration allows idle-in-transaction sessions to persist.
**Impact:** Idle-in-transaction sessions hold transactional resources open and can interfere with vacuum, locking behavior, and connection hygiene.
**Recommendation:** Ensure clients commit or roll back promptly and avoid holding transactions open while idle.
**Urgency:** short_term
**Score effects (high):** concurrency -18, availability -8

---

### 3. active_lock_blocking_detected

**Domain:** concurrency
**Inputs:** `lock_blocking_chains`

| Condition                             | Severity | Confidence |
|---------------------------------------|----------|------------|
| Blocked count > 3                     | high     | high       |
| Any blocking pair exists              | medium   | high       |

**Cause:** Concurrent transactions competing for the same rows, or DDL operations running during active workload without proper coordination.
**Impact:** Blocking chains can directly increase request latency and, in severe cases, trigger incidents.
**Recommendation:** Identify the blocker query pattern, review transaction scope, and optimize access patterns or indexing to reduce lock duration.
**Urgency:** immediate
**Score effects (high):** concurrency -20, performance -12, availability -8

---

### 4. deadlocks_observed

**Domain:** concurrency
**Inputs:** `database_activity`

| Condition     | Severity | Confidence |
|---------------|----------|------------|
| deadlocks > 5 | high     | medium     |
| deadlocks > 0 | medium   | medium     |

Confidence is medium because stats window matters — deadlock count is cumulative since last stats reset.

**Cause:** Application lock ordering is inconsistent, or transactions hold locks across user-facing wait points.
**Impact:** Deadlocks indicate transactional access patterns that can fail user requests and complicate reliability.
**Recommendation:** Review transaction ordering and conflicting write paths, especially around hot rows or tables.
**Urgency:** short_term
**Score effects (high):** concurrency -16, availability -8

---

### 5. high_connection_utilization

**Domain:** concurrency
**Inputs:** `connection_pressure`, `instance_metadata`

| Condition         | Severity | Confidence |
|-------------------|----------|------------|
| utilization > 90% | high     | medium     |
| utilization > 80% | medium   | medium     |

Increase severity if active connections are high and wait events indicate contention.

**Cause:** Missing or misconfigured connection pooling, or max_connections set too low for actual demand.
**Impact:** High connection utilization reduces headroom and raises saturation risk during spikes or incidents.
**Recommendation:** Review pooling posture, reduce idle clients, and ensure max_connections aligns with the deployment model.
**Urgency:** short_term
**Score effects (high):** concurrency -16, availability -8, efficiency -4

---

### 6. significant_temp_spill_activity

**Domain:** performance
**Inputs:** `database_activity`, `temp_spill_queries`

| Condition                       | Severity | Confidence |
|---------------------------------|----------|------------|
| max temp_blks_written > 100,000 | high     | medium     |
| max temp_blks_written > 10,000  | medium   | medium     |

**Workload-sensitive:** Downgrade in OLAP profile unless interactive latency is an objective.

**Cause:** Sort or hash operations exceed work_mem, forcing spill to disk. May also indicate missing indexes causing large intermediate result sets.
**Impact:** Temp spills often indicate expensive sorts or hashes, increasing latency and I/O cost.
**Recommendation:** Review the spilling queries, validate plan shape, and consider targeted query/index changes before adjusting memory settings.
**Urgency:** short_term
**Score effects (high):** performance -16, efficiency -10, cost -8

---

### 7. high_impact_query_total_time

**Domain:** performance
**Inputs:** `top_queries_total_time`

| Condition                        | Severity | Confidence |
|----------------------------------|----------|------------|
| Top total_exec_time > 600,000 ms | high     | medium     |
| Top total_exec_time > 120,000 ms | medium   | medium     |

**Cause:** Inefficient query plans, missing indexes, or suboptimal query design causing a small number of queries to dominate server time.
**Impact:** Queries dominating total server time are the best optimization leverage points for performance and cost.
**Recommendation:** Start with the top total-time query, inspect its execution plan, and validate indexing and row-access patterns.
**Urgency:** structural
**Score effects (high):** performance -14, efficiency -8, cost -6

---

### 8. high_latency_queries_detected

**Domain:** performance
**Inputs:** `top_queries_mean_latency`

| Condition                             | Severity | Confidence |
|---------------------------------------|----------|------------|
| workload = OLTP AND top mean > 500 ms | high     | medium     |
| top mean > 1,000 ms (any workload)    | medium   | medium     |

**Workload-sensitive:** Increase severity in OLTP; decrease in OLAP unless user-facing path involved.

**Cause:** Missing indexes, suboptimal query plans, or lock contention causing queries to wait.
**Impact:** Slow queries directly affect response time, and in OLTP workloads can degrade user-visible service quality.
**Recommendation:** Inspect the slowest queries first, compare plan shape to expected selectivity, and confirm whether the workload is OLTP or analytical.
**Urgency:** short_term
**Score effects (high):** performance -18, concurrency -6

---

### 9. dead_tuple_accumulation_detected

**Domain:** storage
**Inputs:** `dead_tuple_ratio`

| Condition              | Severity | Confidence |
|------------------------|----------|------------|
| max dead tuple % > 30% | high     | high       |
| max dead tuple % > 10% | medium   | high       |

Deprioritize small tables. Increase severity if paired with long transactions or stale vacuum.

**Cause:** Autovacuum cannot reclaim dead tuples because long-running transactions hold back the visibility horizon, or autovacuum settings are insufficient for write volume.
**Impact:** Dead tuples can degrade scan performance, increase storage usage, and indicate that vacuum is not keeping up.
**Recommendation:** Review autovacuum effectiveness, long-lived transactions, and high-churn tables contributing to dead tuple growth.
**Urgency:** short_term
**Score effects (high):** storage -18, performance -8, availability -4

---

### 10. stale_vacuum_or_analyze_detected

**Domain:** operational_hygiene
**Inputs:** `stale_maintenance`

| Condition                                       | Severity | Confidence |
|-------------------------------------------------|----------|------------|
| tables missing autoanalyze AND > 1M live tuples | high     | medium     |
| any stale tables detected                       | medium   | medium     |

**Cause:** Autovacuum thresholds are too conservative for table write volume, or autovacuum workers are saturated and cannot keep up.
**Impact:** Stale maintenance can reduce planner quality and allow dead tuple accumulation to persist.
**Recommendation:** Verify autovacuum settings and throughput, and confirm that large or hot tables are receiving timely analyze/vacuum coverage.
**Urgency:** short_term
**Score effects (high):** operational_hygiene -14, storage -6, performance -4

---

### 11. potentially_unused_large_indexes

**Domain:** storage
**Inputs:** `unused_indexes`

| Condition                         | Severity | Confidence |
|-----------------------------------|----------|------------|
| ≥ 3 large indexes with zero scans | medium   | low        |
| ≥ 1 large index with zero scans   | low      | low        |

**Never high in v1** without longer stats horizon. "Large" means ≥ 100 MiB.

**Cause:** Indexes created during earlier development or schema iterations that are no longer used by any query path.
**Impact:** Unused indexes increase storage footprint and write amplification.
**Recommendation:** Validate over a representative stats window before removal, then drop clearly redundant or obsolete indexes carefully.
**Urgency:** structural
**Score effects (medium):** storage -8, efficiency -5, cost -5

---

### 12. replication_lag_elevated

**Domain:** availability
**Inputs:** `replication_health`

| Condition                  | Severity | Confidence |
|----------------------------|----------|------------|
| max replay lag > 10,000 ms | high     | medium     |
| max replay lag > 1,000 ms  | medium   | medium     |

Increase severity if replicas serve reads or failover guarantees are strict.

**Cause:** Network latency between primary and replica, high write volume exceeding replica apply rate, or replica resource contention.
**Impact:** Elevated lag can affect failover posture and read freshness when replicas serve reads.
**Recommendation:** Review write rate, replica health, and whether read traffic depends on timely replay.
**Urgency:** immediate
**Score effects (high):** availability -18, performance -4

---

### 13. checkpoint_pressure_detected

**Domain:** efficiency
**Inputs:** `wal_checkpoint_health`

| Condition                                          | Severity | Confidence |
|----------------------------------------------------|----------|------------|
| checkpoints_req > 50 AND buffers_backend > 500,000 | high     | medium     |
| checkpoints_req > 10                               | medium   | medium     |

**Cause:** max_wal_size or checkpoint_timeout too low for write volume, causing frequent forced checkpoints and backend write pressure.
**Impact:** Excessive checkpoint pressure can increase write latency and backend write work.
**Recommendation:** Review checkpoint cadence, WAL volume, and write-heavy query patterns before changing memory or checkpoint settings.
**Urgency:** structural
**Score effects (high):** efficiency -16, performance -6, availability -4, cost -4

---

### 14. diagnostic_visibility_limited

**Domain:** operational_hygiene
**Inputs:** `extensions_inventory`

| Condition                 | Severity | Confidence |
|---------------------------|----------|------------|
| pg_stat_statements absent | medium   | high       |

This is a **meta-finding** — not a system defect, but a diagnostic quality concern.

**Cause:** pg_stat_statements not included in shared_preload_libraries, or extension not created in the database.
**Impact:** Limited observability reduces diagnostic confidence and can delay root-cause analysis.
**Recommendation:** Enable and retain key diagnostic views or extensions, especially pg_stat_statements, where supported by platform policy.
**Urgency:** structural
**Score effects:** operational_hygiene -10

---

### 15. storage_concentration_risk

**Domain:** storage
**Inputs:** `largest_tables`

| Condition            | Severity | Confidence |
|----------------------|----------|------------|
| top relation > 10 GB | medium   | high       |

Becomes more relevant when cost or maintenance is a primary objective.

**Cause:** Natural data growth concentrated in a few high-traffic tables, or lack of partitioning/archiving strategy.
**Impact:** Storage concentrated in a few large relations can amplify maintenance, bloat, and cost issues.
**Recommendation:** Focus storage and maintenance analysis on the largest relations first, especially those with high churn or large index footprints.
**Urgency:** structural
**Score effects:** storage -8, cost -6, efficiency -3

---

### 16. diagnostic_configuration_weak

**Domain:** operational_hygiene
**Inputs:** `instance_metadata`

| Condition                                                                                  | Severity | Confidence |
|--------------------------------------------------------------------------------------------|----------|------------|
| `track_io_timing = off` AND `log_min_duration_statement = -1` | medium   | high       |
| Any one of these is suboptimal                                                             | low      | high       |

**Cause:** Key diagnostic settings are disabled in the PostgreSQL configuration.
**Impact:** Weak diagnostic configuration makes root-cause analysis difficult and hides performance bottlenecks.
**Recommendation:** Enable `track_io_timing`, configure `log_min_duration_statement` to a reasonable threshold (e.g., 100ms), and ensure `pg_stat_statements` is active.
**Urgency:** structural
**Score effects (medium):** operational_hygiene -10

---

### 17. excessive_superuser_roles

**Domain:** operational_hygiene
**Inputs:** `role_inventory`

| Condition                                     | Severity | Confidence |
|-----------------------------------------------|----------|------------|
| > 2 roles with `SUPERUSER`                    | medium   | high       |
| > 1 role with `SUPERUSER` (beyond `postgres`) | low      | high       |

**Cause:** Roles granted superuser privileges during initial setup or debugging and never revoked.
**Impact:** Superuser proliferation increases the blast radius of credential compromise and bypasses RLS.
**Recommendation:** Revoke superuser from non-system roles and follow the principle of least privilege.
**Urgency:** short_term
**Score effects (medium):** operational_hygiene -10, availability -4

**Note:** Superuser roles bypass all permission checks including RLS. Proliferation increases blast radius of credential compromise. Roles with `SUPERUSER` + `LOGIN` + no `VALID UNTIL` are the highest risk.

---

## Supabase-Specific Findings

### 18. rls_policy_columns_unindexed

**Domain:** performance
**Inputs:** `rls_policy_column_indexing`

| Condition                              | Severity | Confidence |
|----------------------------------------|----------|------------|
| > 5 unindexed RLS policy columns       | high     | high       |
| > 2 unindexed RLS policy columns       | medium   | high       |

**Cause:** Missing indexes on columns referenced in RLS USING/WITH CHECK clauses.
**Impact:** Every API call through PostgREST pays the RLS tax; missing indexes on policy columns turn this into a sequential scan on every request.
**Recommendation:** Add indexes to all columns used in RLS USING and WITH CHECK clauses.
**Urgency:** short_term
**Score effects (high):** performance -20, efficiency -10

---

### 19. replication_slot_inactive_or_lagging

**Domain:** availability
**Inputs:** `realtime_replication_slot_health`

| Condition                        | Severity | Confidence |
|----------------------------------|----------|------------|
| Inactive slot with lag > 1GB     | critical | high       |
| Lag > 500MB or inactive > 1 hour | high     | high       |
| Lag > 100MB                      | medium   | high       |

**Cause:** Unconsumed replication slots prevent WAL cleanup, often due to an inactive logical replication consumer (like Supabase Realtime).
**Impact:** Unconsumed or inactive slots prevent WAL cleanup and can fill disk, leading to database unavailability.
**Recommendation:** Identify the unconsumed slot and ensure the consumer is active, or drop the slot if it is no longer needed.
**Urgency:** immediate
**Score effects (critical):** availability -25, storage -15

---

### 20. auth_table_bloat_detected

**Domain:** storage
**Inputs:** `auth_schema_health`

| Condition                                                | Severity | Confidence |
|----------------------------------------------------------|----------|------------|
| dead_tuple_pct > 30% OR row count > 5M with stale vacuum | high     | high       |
| dead_tuple_pct > 10% OR row count > 1M                   | medium   | high       |

**Cause:** High churn on auth tables (sessions and refresh_tokens) exceeding autovacuum reclaim rate.
**Impact:** Auth tables experience high churn; stale vacuum on these tables slows login flows and bloats storage.
**Recommendation:** Tune autovacuum for the auth schema and ensure long-running transactions are not blocking cleanup.
**Urgency:** short_term
**Score effects (high):** storage -15, performance -8, availability -5

---

### 21. storage_soft_delete_pressure

**Domain:** storage
**Inputs:** `storage_objects_health`

| Condition                                     | Severity | Confidence |
|-----------------------------------------------|----------|------------|
| soft_deleted_ratio > 20%                      | high     | medium     |

**Cause:** Large number of soft-deleted objects in storage.objects that have not been purged.
**Impact:** storage.objects can grow very large in file-heavy applications; soft-deleted rows waste storage and slow queries.
**Recommendation:** Review storage cleanup policies and ensure soft-deleted objects are purged regularly.
**Urgency:** short_term
**Score effects (high):** storage -12, cost -8

---

### 22. system_schema_vacuum_stale

**Domain:** operational_hygiene
**Inputs:** `system_schema_bloat`

| Condition                                                                       | Severity | Confidence |
|---------------------------------------------------------------------------------|----------|------------|
| max dead_tuple_pct > 30% across system schema tables                            | high     | high       |

**Cause:** Platform-managed tables (auth, storage, realtime) not receiving adequate autovacuum coverage.
**Impact:** System schemas are managed by the platform but still need vacuum; high dead tuple ratios indicate maintenance gaps.
**Recommendation:** Alert platform engineering or tune autovacuum for system tables where customer-tunable.
**Urgency:** short_term
**Score effects (high):** operational_hygiene -15, storage -8, performance -5

---

### 23. pool_mode_misconfiguration

**Domain:** performance
**Inputs:** `pgbouncer_pool_health`

| Condition                                         | Severity | Confidence |
|---------------------------------------------------|----------|------------|
| Transaction mode detected                         | low      | medium     |

**Cause:** Connection pooler (PgBouncer/Supavisor) configured in transaction mode when prepared statements are required.
**Impact:** Transaction mode breaks prepared statement caching, causing repeated planning overhead for every query.
**Recommendation:** Use session mode for workloads requiring prepared statements, or optimize application to use transaction-mode-safe patterns.
**Urgency:** structural
**Score effects (low):** performance -4

---

### 24. pg_cron_job_failures

**Domain:** operational_hygiene
**Inputs:** `pg_cron_job_health`

| Condition                                        | Severity | Confidence |
|--------------------------------------------------|----------|------------|
| Any job failure detected                         | medium   | high       |

**Cause:** Scheduled pg_cron jobs failing due to logic errors, permission issues, or resource contention.
**Impact:** Failed background jobs can indicate logic errors, resource contention, or silent failures in maintenance tasks.
**Recommendation:** Check `cron.job_run_details` for specific error messages and validate job dependencies.
**Urgency:** short_term
**Score effects (medium):** operational_hygiene -10, availability -5

---

### 25. extension_version_outdated

**Domain:** operational_hygiene
**Inputs:** `extension_version_health`

| Condition                                         | Severity | Confidence |
|---------------------------------------------------|----------|------------|
| Any extension outdated                            | low      | low        |

**Cause:** Database extensions have available upgrades that have not been applied.
**Impact:** Outdated extensions may miss security patches, bug fixes, or performance improvements.
**Recommendation:** Upgrade extensions during a scheduled maintenance window after testing for compatibility.
**Urgency:** structural
**Score effects (low):** operational_hygiene -4

---

### 26. pgvector_missing_index

**Domain:** performance
**Inputs:** `pgvector_index_health`

| Condition                                                          | Severity | Confidence |
|--------------------------------------------------------------------|----------|------------|
| Any unindexed vector column detected                               | high     | high       |

**Cause:** Vector columns exist on large tables but lack specialized HNSW or IVFFlat indexes.
**Impact:** Missing vector indexes cause expensive sequential distance scans, dramatically increasing latency for AI/search features.
**Recommendation:** Add HNSW or IVFFlat indexes to all frequently queried vector columns.
**Urgency:** short_term
**Score effects (high):** performance -15, efficiency -8

---

### 27. pgvector_index_misconfigured

**Domain:** performance
**Inputs:** `pgvector_index_health`

| Condition                                                          | Severity | Confidence |
|--------------------------------------------------------------------|----------|------------|
| HNSW index with default parameters on table > 500K rows           | medium   | medium     |
| IVFFlat index with lists < sqrt(row_count)                        | medium   | medium     |

**Cause:** Vector index parameters were left at defaults or set without accounting for dataset size, leading to suboptimal recall or excessive memory usage.
**Impact:** Misconfigured vector indexes degrade search quality (low recall) or consume unnecessary memory, affecting both accuracy and performance of AI/search features.
**Recommendation:** Review HNSW `m` and `ef_construction` parameters relative to dataset size. For IVFFlat, ensure `lists` is approximately sqrt(row_count). Benchmark recall vs latency after changes.
**Urgency:** structural
**Score effects (medium):** performance -8, efficiency -5

---

### 28. pool_contention_detected

**Domain:** concurrency
**Inputs:** `pgbouncer_pool_health`

| Condition                                        | Severity | Confidence |
|--------------------------------------------------|----------|------------|
| Waiting clients > 10 AND wait duration > 1 second | high     | high       |
| Waiting clients > 0                              | medium   | medium     |

**Cause:** Connection pool is undersized relative to demand, causing clients to queue for available connections.
**Impact:** Pool contention adds latency to every queued request and can cascade into timeouts under load.
**Recommendation:** Increase pool size, reduce per-connection hold time, or add a secondary pooler. Investigate whether idle-in-transaction sessions are consuming pool slots unnecessarily.
**Urgency:** short_term
**Score effects (high):** concurrency -15, performance -8

---

### 29. auth_session_explosion

**Domain:** storage
**Inputs:** `auth_schema_health`

| Condition                                          | Severity | Confidence |
|----------------------------------------------------|----------|------------|
| auth.sessions row count > 10M                      | high     | high       |
| auth.sessions row count > 5M                        | medium   | medium     |

> **v1 note:** Growth rate detection (e.g., "> 1M/week") requires historical data from multiple assessment runs and is deferred to Phase 3. The v1 rule uses threshold-only conditions.

**Cause:** Auth sessions accumulating without adequate cleanup, often due to short-lived anonymous sessions or missing session expiration policies.
**Impact:** Excessive session table size degrades login performance, increases vacuum pressure, and inflates storage costs.
**Recommendation:** Review session retention policies, enable or tune session cleanup jobs, and investigate whether anonymous session creation rate is expected.
**Urgency:** short_term
**Score effects (high):** storage -12, performance -8, availability -5

---

### 30. storage_objects_bloat

**Domain:** storage
**Inputs:** `storage_objects_health`

| Condition                                            | Severity | Confidence |
|------------------------------------------------------|----------|------------|
| storage.objects dead_tuple_pct > 30% AND size > 1 GB | high     | high       |
| storage.objects dead_tuple_pct > 15%                 | medium   | medium     |

**Cause:** High churn on storage.objects (frequent uploads, deletions, or metadata updates) outpacing autovacuum reclaim rate.
**Impact:** Bloated storage.objects table slows file listing queries and wastes disk space beyond the actual file metadata footprint.
**Recommendation:** Tune autovacuum for storage.objects (lower threshold, higher scale factor for this table). Investigate whether soft-delete cleanup is running.
**Urgency:** short_term
**Score effects (high):** storage -12, cost -6

## Most Actionable Findings (v1 priority)

1. Long-running transactions
2. Idle in transaction
3. Blocking chains
4. Slow / high-impact queries
5. Temp spill behavior
6. Dead tuple accumulation
7. Stale vacuum / analyze
8. Elevated replication lag
