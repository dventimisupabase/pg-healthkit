# V1 Findings Catalog

This document defines the 15 v1 findings with their logic, inputs, severity gradation, and domain effects. For the machine-readable rule definitions, see `rules.yaml`.

## Finding Structure

Each finding includes:

| Field            | Purpose                                           |
|------------------|---------------------------------------------------|
| Field            | Purpose                                                                           |
|------------------|-----------------------------------------------------------------------------------|
| `finding_key`    | Stable identifier for the issue class                                             |
| `domain`         | Primary health domain                                                             |
| `severity`       | Operational/business importance (info → critical)                                 |
| `confidence`     | How trustworthy the inference is                                                  |
| `title`          | Human-readable title                                                              |
| `summary`        | What was observed                                                                 |
| `cause`          | Likely root cause (not symptoms)                                                  |
| `impact`         | Why it matters                                                                    |
| `recommendation` | What to do                                                                        |
| `urgency`        | Remediation timeframe: `immediate` (1 week), `short_term` (30 days), `structural` (quarter) |
| `evidence_refs`  | Links to supporting probe evidence                                                |
| `tags`           | Classification labels                                                             |

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
| Blockers include DDL or very old xact | critical | high       |

**Cause:** Concurrent transactions competing for the same rows, or DDL operations running during active workload without proper coordination.
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
**Urgency:** structural
**Score effects:** storage -8, cost -6, efficiency -3

### 16. excessive_superuser_roles

**Domain:** operational_hygiene
**Inputs:** `role_inventory`

| Condition                                     | Severity | Confidence |
|-----------------------------------------------|----------|------------|
| > 2 roles with `SUPERUSER`                    | medium   | high       |
| > 1 role with `SUPERUSER` (beyond `postgres`) | low      | high       |

**Score effects (medium):** operational_hygiene -10, availability -4

**Cause:** Roles granted superuser privileges during initial setup or debugging and never revoked.
**Urgency:** short_term

**Note:** Superuser roles bypass all permission checks including RLS. Proliferation increases blast radius of credential compromise. Roles with `SUPERUSER` + `LOGIN` + no `VALID UNTIL` are the highest risk.

---

## Supabase-Specific Findings

### 17. rls_policy_columns_unindexed

**Domain:** performance
**Inputs:** `rls_policy_column_indexing`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| > 5 tables with unindexed RLS columns | high | high |
| > 2 tables with unindexed RLS columns | medium | high |
| Any table with unindexed RLS columns | low | high |

**Score effects (high):** performance -20, efficiency -10

**Note:** Possibly the single highest-impact Supabase-specific finding. RLS is enabled by default on all Supabase tables exposed through PostgREST. Every API call pays the RLS tax; missing indexes on policy columns turn this into a sequential scan on every request.

---

### 18. replication_slot_inactive_or_lagging

**Domain:** availability
**Inputs:** `realtime_replication_slot_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Inactive slot with lag > 1GB | critical | high |
| Lag > 500MB or inactive > 1 hour | high | high |
| Lag > 100MB | medium | high |

**Score effects (critical):** availability -25, storage -15

**Note:** Supabase Realtime uses logical replication slots. Unconsumed or inactive slots prevent WAL cleanup and can fill disk, leading to database unavailability.

---

### 19. auth_table_bloat_detected

**Domain:** storage
**Inputs:** `auth_schema_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| dead_tuple_pct > 30% OR row count > 5M with stale vacuum | high | high |
| dead_tuple_pct > 10% OR row count > 1M | medium | high |

**Score effects (high):** storage -15, performance -8, availability -5

**Note:** Auth tables (especially auth.sessions and auth.refresh_tokens) experience high churn. Stale vacuum on these tables slows login flows and bloats storage.

---

### 20. storage_soft_delete_pressure

**Domain:** storage
**Inputs:** `storage_objects_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| soft_deleted_ratio > 20% AND table size > 1GB | high | medium |
| soft_deleted_ratio > 10% | medium | medium |

**Score effects (high):** storage -12, cost -8

**Note:** storage.objects can grow very large in file-heavy applications. Soft-deleted rows that aren't cleaned up waste storage and slow queries.

---

### 21. system_schema_vacuum_stale

**Domain:** operational_hygiene
**Inputs:** `system_schema_bloat`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Any system table > 1M rows with no autovacuum in 7 days OR dead_tuple_pct > 30% | high | high |
| dead_tuple_pct > 10% | medium | high |

**Score effects (high):** operational_hygiene -15, storage -8, performance -5

**Note:** System schemas (auth, storage, realtime, extensions, supabase_functions) are managed by the platform but still need vacuum. Findings should be tagged as "platform" origin to distinguish from user-schema issues.

---

### 22. pool_mode_misconfiguration

**Domain:** performance
**Inputs:** `pgbouncer_pool_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Transaction mode with high planning time overhead | medium | medium |
| Transaction mode detected (informational) | low | medium |

**Score effects (medium):** performance -8, concurrency -5

**Note:** Transaction mode breaks prepared statement caching, causing repeated planning overhead. This is informational unless paired with evidence of planning time impact.

---

### 23. pg_cron_job_failures

**Domain:** operational_hygiene
**Inputs:** `pg_cron_job_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Multiple recent failures or critical job failing | high | high |
| Any job failure detected | medium | medium |

**Score effects (high):** operational_hygiene -10, availability -5

**Note:** Failed cron jobs may indicate schema issues, permission problems, or resource contention.

---

### 24. extension_version_outdated

**Domain:** operational_hygiene
**Inputs:** `extension_version_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Critical extensions outdated by multiple versions | medium | medium |
| Any extension outdated | low | low |

**Score effects (medium):** operational_hygiene -8

**Note:** On Supabase, extension upgrades are sometimes tied to platform version upgrades. Outdated extensions may miss security patches or performance improvements.

---

### 25. pgvector_missing_index

**Domain:** performance
**Inputs:** `pgvector_index_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Large tables (> 100K rows) with vector columns but no vector index | high | high |
| Any table with vector columns but no vector index | medium | medium |

**Score effects (high):** performance -15, efficiency -8

**Note:** Missing vector indexes cause sequential distance scans. HNSW with default parameters may not suit the dataset size. IVFFlat with too few lists reduces recall.

## Most Actionable Findings (v1 priority)

1. Long-running transactions
2. Idle in transaction
3. Blocking chains
4. Slow / high-impact queries
5. Temp spill behavior
6. Dead tuple accumulation
7. Stale vacuum / analyze
8. Elevated replication lag
