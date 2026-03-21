# SQL-Contract Structural Alignment

**Date**: 2026-03-21
**Status**: Approved
**Scope**: Expand `contracts/probe_registry.yaml` to include all fields SQL probes actually produce. Fix SQL aliases in 2 probe files.

## Problem

An audit of all 25 SQL probes against `probe_registry.yaml` found 15 probes where the SQL outputs fields not documented in the contract. This causes confusion for implementers and means the normalizer has undocumented input fields.

## Approach

**Contracts expand to match SQL.** The SQL probes reflect what PostgreSQL actually provides — they are closer to ground truth. The registry should document all available fields so implementers and future rule authors know what data exists.

## Strategy

- Every column a SQL probe outputs gets a corresponding entry in the registry's `payload_contract`
- Fields already in the contract stay as-is
- New fields get `type` and `optional: true` if no rule in `rules.yaml` currently consumes them
- Existing contract structure (nesting, summary objects) is preserved
- 2 SQL files are edited where aliases don't match contract required field names
- Normalizer docs are deferred to implementation time

## Probes With No Changes Needed

These 10 probes passed the audit — SQL output matches contract:

- lock_blocking_chains (13)
- temp_spill_queries (22)
- largest_tables (30)
- dead_tuple_ratio (31)
- unused_indexes (33)
- replication_health (40)
- role_inventory (50)
- rls_policy_column_indexing (60)
- system_schema_bloat (64)
- pgbouncer_pool_health (65) — contract was relaxed in a prior residuals fix; SQL now aligns

## Per-Probe Changes

### Major structural (contract needs significant expansion)

#### instance_metadata (00)
The SQL outputs 16 flat columns. The contract already has `server_version_num`, `is_replica`, and all settings fields nested under `settings`. Two fields need to be added:
- Add `db` (string, optional) — the database name connected to
- Add `version` (string, optional) — human-readable PG version string (maps to contract's `postgres_version` via normalizer)

Note: the SQL column `version` corresponds to the contract field `postgres_version`. This rename is the normalizer's job.

#### extensions_inventory (01)
Add `extname` (string) and `extversion` (string) as row-level properties documenting the raw SQL output columns. The contract's `extensions` array with `name`/`version` fields is the normalized form. Summary fields (`extension_count`, `has_pg_stat_statements`) remain derived by normalizer.

#### database_activity (10)
Add these as optional properties under the `stats` object (matching the contract's existing nesting structure). The SQL outputs them as flat columns; the normalizer nests them under `stats`:
- `numbackends` (integer)
- `tup_returned` (bigint)
- `tup_fetched` (bigint)
- `tup_inserted` (bigint)
- `tup_updated` (bigint)
- `tup_deleted` (bigint)
- `stats_reset` (timestamp, nullable)

#### connection_pressure (11)
The SQL currently produces only summary data — Part 2 of the query (which would produce the `states` array) is commented out. Change: remove `states` from the `required` array in the contract. Keep the `states` type definition in properties so it's available when Part 2 is enabled.

### Field additions (contract needs new fields)

#### long_running_transactions (12)
Add `client_addr` (string, optional, nullable) as row property.

#### stale_maintenance (32)
The SQL outputs 10 columns. The contract already has `schemaname`, `relname`, `n_live_tup`, `last_autovacuum`, `last_autoanalyze`, `autovacuum_count`, `autoanalyze_count`. Add 3 missing fields:
- `n_dead_tup` (bigint)
- `vacuum_count` (bigint) — manual vacuum count, distinct from `autovacuum_count`
- `analyze_count` (bigint) — manual analyze count, distinct from `autoanalyze_count`

No SQL fix needed.

#### wal_checkpoint_health (41)
Add to bgwriter properties:
- `maxwritten_clean` (bigint, optional)
- `buffers_alloc` (bigint, optional)

Add `wal` object as optional (PG 14+ only). Note: the WAL query (`SELECT * FROM pg_stat_wal`) is currently commented out in the SQL. These fields are aspirational — they document what will be available when the query is enabled. Actual field names should be verified against `pg_stat_wal` view columns for the target PG version when the query is uncommented.

#### realtime_replication_slot_health (61)
Add as optional row properties:
- `slot_type` (string)
- `xmin` (string, nullable)
- `confirmed_flush_lsn` (string, nullable)
- `current_wal_lsn` (string)

#### auth_schema_health (62)
The SQL outputs 10 columns. The contract already has `relname`, `n_dead_tup`, `dead_tuple_pct`, `n_live_tup`, `last_autovacuum`. Add 5 missing fields:
- `schemaname` (string)
- `last_vacuum` (timestamp, nullable)
- `last_analyze` (timestamp, nullable)
- `last_autoanalyze` (timestamp, nullable)
- `total_bytes` (bigint)

#### storage_objects_health (63)
The SQL is a single-row query filtered to `storage.objects`. The contract currently has only `summary` fields. Add row-level properties to document the raw SQL output:
- `schemaname` (string)
- `relname` (string)
- `total_rows` (bigint)
- `soft_deleted_rows` (bigint)
- `soft_deleted_ratio` (numeric)
- `n_live_tup` (bigint)
- `n_dead_tup` (bigint)
- `dead_tuple_pct` (numeric)
- `last_autovacuum` (timestamp, nullable)
- `last_autoanalyze` (timestamp, nullable)
- `total_bytes` (bigint)

Note: this probe always returns exactly one row. Summary fields are derived directly from this row's values.

### SQL alias fixes (2 files edited)

#### pg_cron_job_health (66)
- **SQL fix**: `j.command` currently has implicit alias `command`. Change to `j.command AS jobname` to match contract required field. Note: `pg_cron` has no separate job name column — the command text serves as the de facto job identifier, so `jobname` is intentionally the command string. `d.start_time` currently has implicit alias `start_time`. Change to `d.start_time AS last_run_time` to match contract required field.
- **Contract addition**: Add these optional row properties for extra SQL columns: `jobid` (bigint), `schedule` (string), `nodename` (string), `nodeport` (integer), `database` (string), `username` (string), `job_active` (boolean), `runid` (bigint, nullable), `job_pid` (integer, nullable), `return_message` (string, nullable), `end_time` (timestamp, nullable), `duration_seconds` (numeric, nullable).

#### pgvector_index_health (68)
- **SQL fix 1 (semantic polarity inversion)**: Change `CASE WHEN vi.index_name IS NULL THEN true ELSE false END AS missing_vector_index` to `vi.index_name IS NOT NULL AS has_index`. This inverts the boolean polarity — `has_index = true` means index exists, matching the contract field name. Any normalizer or rule logic referencing this field must use `has_index` (true = indexed) not `missing_vector_index` (true = missing).
- **SQL fix 2**: Change `c.relname AS table_name` to `c.relname AS tablename` (no underscore) to match contract field name. This alias appears in the final SELECT; update there.
- **Contract addition**: Add these optional row properties: `schemaname` (string), `column_type` (string), `row_count` (bigint), `index_name` (string, nullable), `index_type` (string, nullable), `index_bytes` (bigint, nullable), `index_def` (string, nullable).

### Minor (extra fields only)

#### top_queries_total_time (20)
The contract already has `queryid`, `query`, `calls`, `total_exec_time_ms`, `mean_exec_time_ms`, `rows`, `shared_blks_hit`, `shared_blks_read`, `temp_blks_written`. Add 4 missing optional fields:
- `min_exec_time_ms` (numeric)
- `max_exec_time_ms` (numeric)
- `stddev_exec_time_ms` (numeric)
- `temp_blks_read` (bigint)

#### top_queries_mean_latency (21)
The contract already has `queryid`, `query`, `calls`, `mean_exec_time_ms`. Add 6 missing optional fields:
- `max_exec_time_ms` (numeric)
- `stddev_exec_time_ms` (numeric)
- `total_exec_time_ms` (numeric)
- `rows` (bigint)
- `shared_blks_hit` (bigint)
- `shared_blks_read` (bigint)

Note: SQL outputs `temp_blks_written` but not `temp_blks_read`. Only add fields the SQL actually produces.

#### extension_version_health (67)
Add `upgrade_available` (boolean, optional) as row property.

## Out of Scope

- Normalizer derivation docs (deferred to implementation)
- Rule or finding changes (new optional fields don't affect existing rules)
- SQL query logic (we don't change what data probes collect, only fix 2 alias names)
- Summary field derivation (normalizer's job)

## Success Criteria

1. Every field that every SQL probe outputs has a corresponding entry in `probe_registry.yaml`
2. The 2 SQL alias fixes (probes 66, 68) make raw output match contract required field names
3. No contract field references a column the SQL doesn't produce (except explicitly marked optional/derived)
4. A `/grok` pass finds zero new SQL-vs-contract mismatches
