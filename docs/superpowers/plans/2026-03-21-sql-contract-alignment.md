# SQL-Contract Structural Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `contracts/probe_registry.yaml` so every field every SQL probe outputs is documented, and fix 2 SQL alias naming errors.

**Architecture:** Contract-first alignment. The registry is updated probe-by-probe to include all SQL output columns. Two SQL files get alias fixes where column names don't match contract required fields. No normalizer, rule, or application code changes.

**Tech Stack:** YAML (probe_registry.yaml), SQL (2 probe files)

**Spec:** `docs/superpowers/specs/2026-03-21-sql-contract-alignment-design.md`

**Type note:** The registry uses `integer` for all integer types (including PostgreSQL's `bigint`). Timestamps are represented as `string` with `nullable: true`. Numeric/decimal values use `number`.

---

### Task 1: SQL Alias Fixes

Fix the 2 SQL files where aliases don't match contract required field names. Do these first so the SQL and contract are consistent when we expand the contracts.

**Files:**
- Modify: `probes/66_pg_cron_job_health.sql`
- Modify: `probes/68_pgvector_index_health.sql`

- [ ] **Step 1: Fix pg_cron_job_health aliases**

In `probes/66_pg_cron_job_health.sql`, make two changes in the SELECT:
- Change `j.command` (implicit alias `command`) to `j.command AS jobname`
- Change `d.start_time` (implicit alias `start_time`) to `d.start_time AS last_run_time`

- [ ] **Step 2: Fix pgvector_index_health aliases**

In `probes/68_pgvector_index_health.sql`, make these changes:
- In the CTE `vector_columns` (~line 10): change `c.relname AS table_name` to `c.relname AS tablename`
- In the final SELECT (~line 39): update the reference from `vc.table_name` to `vc.tablename`
- In the final SELECT: change `CASE WHEN vi.index_name IS NULL THEN true ELSE false END AS missing_vector_index` to `vi.index_name IS NOT NULL AS has_index`

- [ ] **Step 3: Commit SQL fixes**

```bash
git add probes/66_pg_cron_job_health.sql probes/68_pgvector_index_health.sql
git commit -m "fix: align SQL probe aliases with contract field names

pg_cron_job_health: command->jobname, start_time->last_run_time
pgvector_index_health: missing_vector_index->has_index (inverted), table_name->tablename"
```

---

### Task 2: Expand Contracts — Major Structural Probes

Update `probe_registry.yaml` for the 4 probes with significant structural gaps.

**Files:**
- Modify: `contracts/probe_registry.yaml`

- [ ] **Step 1: Read the registry file**

Read `contracts/probe_registry.yaml` to understand the current structure and field patterns for each probe being modified.

- [ ] **Step 2: Update instance_metadata (00)**

Add to the `instance_metadata` payload_contract properties:
- `db`: `{type: string, optional: true}` — database name connected to
- `version`: `{type: string, optional: true}` — human-readable PG version (normalizer maps to `postgres_version`)

- [ ] **Step 3: Update extensions_inventory (01)**

The current contract has an `extensions` array with `name`/`version` fields — that's the normalized form. Add a `raw_row_properties` comment block (or a sibling section) documenting the raw SQL output columns that the normalizer receives as input:
- `extname`: `{type: string}` — raw extension name (normalizer maps to `name`)
- `extversion`: `{type: string}` — raw extension version (normalizer maps to `version`)

If the registry has no convention for documenting raw-vs-normalized fields, add these as additional properties in the existing row items with a comment noting they are raw SQL column names.

- [ ] **Step 4: Update database_activity (10)**

Add to the `database_activity` payload_contract under the existing `stats` object properties (the contract already nests stats fields under `stats`):
- `numbackends`: `{type: integer, optional: true}`
- `tup_returned`: `{type: integer, optional: true}`
- `tup_fetched`: `{type: integer, optional: true}`
- `tup_inserted`: `{type: integer, optional: true}`
- `tup_updated`: `{type: integer, optional: true}`
- `tup_deleted`: `{type: integer, optional: true}`
- `stats_reset`: `{type: string, nullable: true, optional: true}` — ISO timestamp

- [ ] **Step 5: Update connection_pressure (11)**

Remove `states` from the `required` array. Keep the `states` type definition in properties unchanged so it's available when Part 2 of the SQL query is enabled.

- [ ] **Step 6: Commit major structural changes**

```bash
git add contracts/probe_registry.yaml
git commit -m "feat: expand contracts for instance_metadata, extensions_inventory, database_activity, connection_pressure"
```

---

### Task 3: Expand Contracts — Field Additions

Update `probe_registry.yaml` for the 7 probes that need additional fields.

**Files:**
- Modify: `contracts/probe_registry.yaml`

- [ ] **Step 1: Update long_running_transactions (12)**

Add to row properties:
- `client_addr`: `{type: string, nullable: true, optional: true}`

- [ ] **Step 2: Update stale_maintenance (32)**

The contract already has `schemaname`, `relname`, `n_live_tup`, `last_autovacuum`, `last_autoanalyze`, `autovacuum_count`, `autoanalyze_count`. Add 3 missing fields to row properties:
- `n_dead_tup`: `{type: integer}`
- `vacuum_count`: `{type: integer}` — manual vacuum count (distinct from existing `autovacuum_count`)
- `analyze_count`: `{type: integer}` — manual analyze count (distinct from existing `autoanalyze_count`)

- [ ] **Step 3: Update wal_checkpoint_health (41)**

Add to the existing `bgwriter` object properties:
- `maxwritten_clean`: `{type: integer, optional: true}`
- `buffers_alloc`: `{type: integer, optional: true}`

The contract already has a `wal` object (with `wal_records` and `wal_bytes`). Do NOT create a new one. The existing `wal` object is optional and marked for PG 14+. The WAL query is currently commented out in the SQL. No changes needed to the `wal` object at this time.

- [ ] **Step 4: Update realtime_replication_slot_health (61)**

Add to row properties:
- `slot_type`: `{type: string, optional: true}`
- `xmin`: `{type: string, nullable: true, optional: true}`
- `confirmed_flush_lsn`: `{type: string, nullable: true, optional: true}`
- `current_wal_lsn`: `{type: string, optional: true}`

- [ ] **Step 5: Update auth_schema_health (62)**

The contract already has `relname`, `n_dead_tup`, `dead_tuple_pct`, `n_live_tup`, `last_autovacuum`. Add 5 missing fields to row properties:
- `schemaname`: `{type: string}`
- `last_vacuum`: `{type: string, nullable: true, optional: true}`
- `last_analyze`: `{type: string, nullable: true, optional: true}`
- `last_autoanalyze`: `{type: string, nullable: true, optional: true}`
- `total_bytes`: `{type: integer}`

- [ ] **Step 6: Update storage_objects_health (63)**

Add a `rows` section to the payload_contract with these properties:
- `schemaname`: `{type: string}`
- `relname`: `{type: string}`
- `total_rows`: `{type: integer}`
- `soft_deleted_rows`: `{type: integer}`
- `soft_deleted_ratio`: `{type: number}`
- `n_live_tup`: `{type: integer}`
- `n_dead_tup`: `{type: integer}`
- `dead_tuple_pct`: `{type: number}`
- `last_autovacuum`: `{type: string, nullable: true}`
- `last_autoanalyze`: `{type: string, nullable: true}`
- `total_bytes`: `{type: integer}`

Add a comment noting this probe always returns exactly one row.

- [ ] **Step 7: Commit field addition changes**

```bash
git add contracts/probe_registry.yaml
git commit -m "feat: expand contracts for 7 probes with missing field definitions"
```

---

### Task 4: Expand Contracts — SQL Alias Probes + Minor Probes

Update `probe_registry.yaml` for the 2 SQL-alias probes (contract additions) and the 3 minor probes.

**Files:**
- Modify: `contracts/probe_registry.yaml`

- [ ] **Step 1: Update pg_cron_job_health (66)**

Add to row properties:
- `jobid`: `{type: integer, optional: true}`
- `schedule`: `{type: string, optional: true}`
- `nodename`: `{type: string, optional: true}`
- `nodeport`: `{type: integer, optional: true}`
- `database`: `{type: string, optional: true}`
- `username`: `{type: string, optional: true}`
- `job_active`: `{type: boolean, optional: true}`
- `runid`: `{type: integer, nullable: true, optional: true}`
- `job_pid`: `{type: integer, nullable: true, optional: true}`
- `return_message`: `{type: string, nullable: true, optional: true}`
- `end_time`: `{type: string, nullable: true, optional: true}`
- `duration_seconds`: `{type: number, nullable: true, optional: true}`

- [ ] **Step 2: Update pgvector_index_health (68)**

Add to row properties:
- `schemaname`: `{type: string, optional: true}`
- `column_type`: `{type: string, optional: true}`
- `row_count`: `{type: integer, optional: true}`
- `index_name`: `{type: string, nullable: true, optional: true}`
- `index_type`: `{type: string, nullable: true, optional: true}`
- `index_bytes`: `{type: integer, nullable: true, optional: true}`
- `index_def`: `{type: string, nullable: true, optional: true}`

- [ ] **Step 3: Update top_queries_total_time (20)**

Add to row properties (verify these don't already exist before adding):
- `min_exec_time_ms`: `{type: number, optional: true}`
- `max_exec_time_ms`: `{type: number, optional: true}`
- `stddev_exec_time_ms`: `{type: number, optional: true}`
- `temp_blks_read`: `{type: integer, optional: true}`

- [ ] **Step 4: Update top_queries_mean_latency (21)**

First check which of these fields already exist in the contract. The contract may already have `max_exec_time_ms` and `stddev_exec_time_ms`. Only add fields that are not already present:
- `total_exec_time_ms`: `{type: number, optional: true}`
- `rows`: `{type: integer, optional: true}`
- `shared_blks_hit`: `{type: integer, optional: true}`
- `shared_blks_read`: `{type: integer, optional: true}`

Skip any fields already in the contract — do not duplicate them.

- [ ] **Step 5: Update extension_version_health (67)**

Add to row properties:
- `upgrade_available`: `{type: boolean, optional: true}`

- [ ] **Step 6: Commit remaining contract changes**

```bash
git add contracts/probe_registry.yaml
git commit -m "feat: expand contracts for pg_cron, pgvector, top_queries, extension_version probes"
```

---

### Task 5: Verification

Run `/grok` to verify alignment is complete.

- [ ] **Step 1: Run a single /grok pass**

Execute `/grok` (or invoke the grok subagent manually). The pass should find zero new SQL-vs-contract mismatches.

- [ ] **Step 2: Review results**

Check the grok summary:
- **Expected**: 0 new items related to SQL/contract field mismatches
- **Acceptable**: Minor findings unrelated to this alignment work (documentation wording, cross-references, etc.)
- **Not acceptable**: Any finding about SQL output columns not matching the registry

- [ ] **Step 3: Fix any remaining mismatches**

If the grok pass finds SQL/contract issues we missed, fix them and commit.

- [ ] **Step 4: Final commit and push**

```bash
git push
```
