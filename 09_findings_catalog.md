# V1 Findings Catalog

This document defines the 15 v1 findings with their logic, inputs, severity gradation, and domain effects. For the machine-readable rule definitions, see `rules.yaml`.

## Finding Structure

Each finding includes:

| Field | Purpose |
|-------|---------|
| `finding_key` | Stable identifier for the issue class |
| `domain` | Primary health domain |
| `severity` | Operational/business importance (info → critical) |
| `confidence` | How trustworthy the inference is |
| `title` | Human-readable title |
| `summary` | What was observed |
| `impact` | Why it matters |
| `recommendation` | What to do |
| `evidence_refs` | Links to supporting probe evidence |
| `tags` | Classification labels |

## Findings

### 1. long_running_transactions_detected

**Domain:** concurrency
**Inputs:** `long_running_transactions`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Oldest xact > 1 hour | high | high |
| Oldest xact > 15 minutes | medium | high |
| Oldest xact > 5 minutes AND workload = OLTP | low | medium |

Increase severity if state is `idle in transaction`.

**Score effects (high):** concurrency -20, storage -10, availability -8

---

### 2. idle_in_transaction_sessions_detected

**Domain:** concurrency
**Inputs:** `connection_pressure`, `long_running_transactions`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| idle-in-transaction count ≥ 3 AND oldest > 15 min | high | high |
| idle-in-transaction count ≥ 1 AND oldest > 5 min | medium | high |

**Score effects (high):** concurrency -18, availability -8

---

### 3. active_lock_blocking_detected

**Domain:** concurrency
**Inputs:** `lock_blocking_chains`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Blocked count > 3 | high | high |
| Any blocking pair exists | medium | high |
| Blockers include DDL or very old xact | critical | high |

**Score effects (high):** concurrency -20, performance -12, availability -8

---

### 4. deadlocks_observed

**Domain:** concurrency
**Inputs:** `database_activity`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| deadlocks > 5 | high | medium |
| deadlocks > 0 | medium | medium |

Confidence is medium because stats window matters — deadlock count is cumulative since last stats reset.

**Score effects (high):** concurrency -16, availability -8

---

### 5. high_connection_utilization

**Domain:** concurrency
**Inputs:** `connection_pressure`, `instance_metadata`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| utilization > 90% | high | medium |
| utilization > 80% | medium | medium |

Increase severity if active connections are high and wait events indicate contention.

**Score effects (high):** concurrency -16, availability -8, efficiency -4

---

### 6. significant_temp_spill_activity

**Domain:** performance
**Inputs:** `database_activity`, `temp_spill_queries`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| max temp_blks_written > 100,000 | high | medium |
| max temp_blks_written > 10,000 | medium | medium |

**Workload-sensitive:** Downgrade in OLAP profile unless interactive latency is an objective.

**Score effects (high):** performance -16, efficiency -10, cost -8

---

### 7. high_impact_query_total_time

**Domain:** performance
**Inputs:** `top_queries_total_time`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| Top total_exec_time > 600,000 ms | high | medium |
| Top total_exec_time > 120,000 ms | medium | medium |

**Score effects (high):** performance -14, efficiency -8, cost -6

---

### 8. high_latency_queries_detected

**Domain:** performance
**Inputs:** `top_queries_mean_latency`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| workload = OLTP AND top mean > 500 ms | high | medium |
| top mean > 1,000 ms (any workload) | medium | medium |

**Workload-sensitive:** Increase severity in OLTP; decrease in OLAP unless user-facing path involved.

**Score effects (high):** performance -18, concurrency -6

---

### 9. dead_tuple_accumulation_detected

**Domain:** storage
**Inputs:** `dead_tuple_ratio`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| max dead tuple % > 30% | high | high |
| max dead tuple % > 10% | medium | high |

Deprioritize small tables. Increase severity if paired with long transactions or stale vacuum.

**Score effects (high):** storage -18, performance -8, availability -4

---

### 10. stale_vacuum_or_analyze_detected

**Domain:** operational_hygiene
**Inputs:** `stale_maintenance`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| tables missing autoanalyze AND > 1M live tuples | high | medium |
| any stale tables detected | medium | medium |

**Score effects (high):** operational_hygiene -14, storage -6, performance -4

---

### 11. potentially_unused_large_indexes

**Domain:** storage
**Inputs:** `unused_indexes`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| ≥ 3 large indexes with zero scans | medium | low |
| ≥ 1 large index with zero scans | low | low |

**Never high in v1** without longer stats horizon. "Large" means ≥ 100 MiB.

**Score effects (medium):** storage -8, efficiency -5, cost -5

---

### 12. replication_lag_elevated

**Domain:** availability
**Inputs:** `replication_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| max replay lag > 10,000 ms | high | medium |
| max replay lag > 1,000 ms | medium | medium |

Increase severity if replicas serve reads or failover guarantees are strict.

**Score effects (high):** availability -18, performance -4

---

### 13. checkpoint_pressure_detected

**Domain:** efficiency
**Inputs:** `wal_checkpoint_health`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| checkpoints_req > 50 AND buffers_backend > 500,000 | high | medium |
| checkpoints_req > 10 | medium | medium |

**Score effects (high):** efficiency -16, performance -6, availability -4, cost -4

---

### 14. diagnostic_visibility_limited

**Domain:** operational_hygiene
**Inputs:** `extensions_inventory`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| pg_stat_statements absent | medium | high |

This is a **meta-finding** — not a system defect, but a diagnostic quality concern.

**Score effects:** operational_hygiene -10

---

### 15. storage_concentration_risk

**Domain:** storage
**Inputs:** `largest_tables`

| Condition | Severity | Confidence |
|-----------|----------|------------|
| top relation > 10 GB | medium | high |

Becomes more relevant when cost or maintenance is a primary objective.

**Score effects:** storage -8, cost -6, efficiency -3

## Most Actionable Findings (v1 priority)

1. Long-running transactions
2. Idle in transaction
3. Blocking chains
4. Slow / high-impact queries
5. Temp spill behavior
6. Dead tuple accumulation
7. Stale vacuum / analyze
8. Elevated replication lag
