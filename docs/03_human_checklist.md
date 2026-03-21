# Human Assessment Checklist

## Purpose

This is a standalone, human-usable assessment checklist for Phase 1 — before any CLI tooling exists. Any SA, DBA, or support engineer can use this checklist to run a structured health review using only `psql`, platform tools, and customer conversation.

The checklist is organized into 11 sections. Sections A–B establish context. Sections C–G assess health domains. Section H covers capacity and cost. Section I audits configuration. Section J covers security and operational hygiene. Section K defines the expected output.

---

## A. Context and Objectives

These questions must be answered before interpreting any evidence. Context defines the meaning of metrics.

- [ ] What is the database for? (application description)
- [ ] What are the top 3 business-critical applications or services using it?
- [ ] Is the workload primarily transactional (OLTP), analytical (OLAP), or mixed?
- [ ] What are the latency and availability expectations? (SLOs, if any)
- [ ] What recent incidents, outages, or customer complaints exist?
- [ ] Is the primary pain performance, reliability, cost, or growth?

**Who answers:** Customer or account team. These cannot be derived from SQL.

---

## B. Platform and Topology

- [ ] PostgreSQL version
- [ ] Managed or self-hosted
- [ ] HA and failover architecture
- [ ] Number of replicas and replication mode (sync/async)
- [ ] Backup tooling and restore validation cadence
- [ ] Monitoring stack in place (APM, metrics, alerting)

**Who answers:** Platform metadata (auto-derivable at Supabase) or operator.

---

## C. Reliability and Recoverability

- [ ] Are backups succeeding?
- [ ] Have restores been tested recently?
- [ ] Is replication lag bounded and stable?
- [ ] Are WAL generation and retention under control?
- [ ] Are there signs of crash risk or storage exhaustion?
- [ ] Are there long-running transactions preventing cleanup?

**Key probes:** `replication_health`, `wal_checkpoint_health`, `long_running_transactions`

---

## D. Performance and Workload

- [ ] What are the top queries by total time?
- [ ] What are the top queries by mean latency?
- [ ] What are the top queries by call volume?
- [ ] Is there evidence of temp file spill?
- [ ] Is there evidence of lock waits?
- [ ] Is performance degradation periodic or continuous?

**Key probes:** `top_queries_total_time`, `top_queries_mean_latency`, `temp_spill_queries`, `lock_blocking_chains`

---

## E. Storage and Maintenance

- [ ] Largest tables and indexes
- [ ] Suspected table or index bloat
- [ ] Dead tuple accumulation
- [ ] Autovacuum effectiveness (frequency, recency, lag)
- [ ] Analyze freshness (stale statistics → poor plans)
- [ ] Indexes with zero or low usage
- [ ] Missing or duplicated indexes

**Key probes:** `largest_tables`, `dead_tuple_ratio`, `stale_maintenance`, `unused_indexes`

---

## F. Connections and Concurrency

- [ ] Peak connections versus configured `max_connections`
- [ ] Connection pooling present? (PgBouncer, Supavisor, application-level)
- [ ] Idle-in-transaction sessions?
- [ ] Lock trees / blocking chains?
- [ ] Prepared transactions or abandoned sessions?
- [ ] Replica conflicts?

**Key probes:** `connection_pressure`, `long_running_transactions`, `lock_blocking_chains`

## G. Resource Efficiency

- [ ] Cache hit ratio (shared_buffers efficiency)
- [ ] Index hit ratio (index vs sequential scan balance)
- [ ] Temporary file generation (work_mem sufficiency)
- [ ] Checkpoint frequency and write pressure (bgwriter/WAL health)
- [ ] CPU saturation versus utilization (is latency CPU-bound?)
- [ ] I/O patterns (random vs sequential, IOPS saturation)

**Key probes:** `database_activity`, `temp_spill_queries`, `wal_checkpoint_health`, `instance_metadata`

---

## H. Capacity and Cost

- [ ] Data growth rate (if historical data available; otherwise note current size for future comparison)
- [ ] WAL growth rate
- [ ] CPU headroom
- [ ] Memory pressure indicators
- [ ] I/O saturation
- [ ] Storage runway (how long until disk fills?)
- [ ] Overprovisioning or underprovisioning signals

**Key probes:** `largest_tables`, `wal_checkpoint_health`, `instance_metadata`

**Note:** True growth rate requires history, not a single snapshot. If no historical telemetry exists, record current sizes and recommend repeat sampling.

---

## I. Configuration Hygiene

Review these settings against workload type and instance sizing:

- [ ] `shared_buffers` — typically 25% of RAM
- [ ] `work_mem` — per-sort/hash memory; dangerous if high with high concurrency
- [ ] `maintenance_work_mem` — affects vacuum/index build speed
- [ ] `effective_cache_size` — planner hint, typically 50–75% of RAM
- [ ] `max_connections` — is it realistic or dangerously high?
- [ ] `random_page_cost` — should be ~1.1 for SSDs, default 4.0 is for spinning disk
- [ ] `checkpoint_timeout` — default 5min; longer reduces checkpoint frequency
- [ ] `max_wal_size` — controls checkpoint spacing
- [ ] `autovacuum_*` — are thresholds and workers adequate for write volume?
- [ ] `log_min_duration_statement` — is slow query logging enabled? (-1 = disabled)
- [ ] `track_io_timing` — is I/O timing data being collected? (off by default)
- [ ] `shared_preload_libraries` — are required extensions loaded? (pg_stat_statements, auto_explain, etc.)
- [ ] `pg_stat_statements` — is it installed and collecting?

**Key probes:** `instance_metadata`, `extensions_inventory`

---

## J. Security and Operational Hygiene

- [ ] Superuser sprawl — how many roles have `SUPERUSER`? (should be minimal)
- [ ] Unused roles — roles that exist but have never connected or have expired `VALID UNTIL`
- [ ] Network exposure — is the database accessible from untrusted networks?
- [ ] SSL enforced? — are unencrypted connections rejected?
- [ ] Extensions inventory — are any risky or unnecessary extensions installed?
- [ ] Risky settings — `log_statement = 'all'` in production, `fsync = off`, etc.
- [ ] Logging sufficient for diagnosis? — can you reconstruct what happened during an incident?

**Key probes:** `role_inventory`, `extensions_inventory`, `instance_metadata`

---

## K. Output

Every assessment should produce:

- [ ] Top risks — ranked by severity and confidence
- [ ] Score by domain — availability, performance, concurrency, storage, efficiency, cost, operational hygiene
- [ ] Recommended remediations — prioritized by impact vs effort
- [ ] Quick wins — changes achievable within 1 week
- [ ] Strategic recommendations — structural changes for the quarter

Categorize recommendations by urgency:

| Urgency        | Timeframe      | Examples                                                        |
|----------------|----------------|-----------------------------------------------------------------|
| **Immediate**  | Within 1 week  | Kill blocking sessions, terminate abandoned transactions        |
| **Short-term** | Within 30 days | Add missing indexes, tune autovacuum, adjust pool configuration |
| **Structural** | Within quarter | Schema redesign, tier upgrade, application transaction rework   |

---

## Supabase-Specific Addendum

When assessing a Supabase-managed database, add these questions:

### Platform context (auto-derivable)

- [ ] Supabase tier (small/medium/large/xl)
- [ ] Region
- [ ] PgBouncer/Supavisor pool mode (transaction/session)
- [ ] PITR enabled?
- [ ] Realtime enabled?
- [ ] Project age

### Customer-specific questions

- [ ] Are you using Supabase Auth, or an external auth provider?
- [ ] Do you use Realtime subscriptions? Approximately how many concurrent subscribers?
- [ ] Do you use Supabase Storage? Approximately how many files?
- [ ] Do you use pgvector? What embedding dimensions?
- [ ] Have you customized any RLS policies beyond the defaults?
- [ ] Do you have pg_cron jobs? What do they do?

### Supabase-specific checks

- [ ] RLS policy columns indexed? (the #1 Supabase-specific performance issue)
- [ ] Realtime replication slots healthy? (inactive slots prevent WAL cleanup)
- [ ] Auth schema tables vacuumed recently? (auth.sessions and auth.refresh_tokens churn heavily)
- [ ] Storage.objects soft-delete pressure? (un-cleaned soft deletes waste space)
- [ ] System schema bloat? (auth, storage, realtime, extensions schemas need vacuum too)
- [ ] PgBouncer pool contention? (waiting clients, pool sizing)
