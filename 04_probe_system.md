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
| 7  | `largest_tables`            | Identify storage concentration and maintenance hotspots                | Often a context probe feeding other findings                                                   |
| 8  | `dead_tuple_ratio`          | Detect vacuum lag and bloat pressure                                   | Strong, especially paired with long transactions or stale maintenance                          |
| 9  | `stale_maintenance`         | Detect inadequate vacuum/analyze coverage                              | Null timestamps on tiny/cold tables may be harmless; weight by size and activity               |
| 10 | `unused_indexes`            | Detect write/storage waste                                             | Explicitly medium-confidence unless stats age is known                                         |

### Baseline Probes (require pg_stat_statements)

| #  | Probe                      | Purpose                                              | Key Insight                                                                       |
|----|----------------------------|------------------------------------------------------|-----------------------------------------------------------------------------------|
| 11 | `top_queries_total_time`   | Identify queries consuming most total execution time | Leverage probe — feeds recommendations more than health severity                  |
| 12 | `top_queries_mean_latency` | Identify slow queries per-call                       | Interpret in context; slow means different things in OLTP vs OLAP                 |
| 13 | `temp_spill_queries`       | Detect queries spilling to temp files                | Lower confidence for global config recommendations unless repeated across queries |

### Contextual Probes

| #  | Probe                   | Purpose                                          | Key Insight                                                                          |
|----|-------------------------|--------------------------------------------------|--------------------------------------------------------------------------------------|
| 14 | `replication_health`    | Assess lag and replica posture                   | Severity depends on workload and whether replicas serve reads                        |
| 15 | `wal_checkpoint_health` | Assess checkpoint and background writer pressure | Less directly actionable than transaction/locking probes; improves operational depth |

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
- **Primary:** `extensions_inventory`, `stale_maintenance`, `instance_metadata`
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
| `wal_checkpoint_health`     | No                 | No                         | baseline              |

For Supabase, many privilege questions are controlled by platform posture, but the planner should still know when a probe is unavailable.

## Probe Profiles

### `default`
All baseline probes, plus pg_stat_statements probes if available, plus replication probe if relevant.

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

### Second Wave (requires pg_stat_statements)
9. `database_activity`
10. `top_queries_total_time`
11. `top_queries_mean_latency`
12. `temp_spill_queries`

### Third Wave (more operational depth)
13. `replication_health`
14. `wal_checkpoint_health`
15. `unused_indexes`

## Optional v1.1 Probes

Good but not required for a credible first release:
- `vacuum_progress`
- `analyze_progress`
- `cache_hit_ratio`
- `sequential_scan_heavy_tables`
- `role_inventory`
- `bloat_estimate`
- `table_xid_age`
- `prepared_transactions`
- `replica_conflicts`

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
