# Plan: Close Documentation Gaps

## Context

A gap analysis comparing `docs/chatgpt-conversation.md` (the authoritative source) against the 13 numbered inception documents (`01_` through `13_`) identified 6 omissions. This plan addresses all of them through new documents and targeted edits to existing documents.

## Gaps to Close

| # | Gap | Severity | Action |
|---|-----|----------|--------|
| 1 | Human checklist (sections A–J) missing | Major | Create new doc `docs/03_human_checklist.md` |
| 2 | Security concerns underweighted | Moderate | Add security probe + finding to existing docs |
| 3 | Configuration hygiene settings incomplete | Moderate | Expand `instance_metadata` probe coverage |
| 4 | Action plan timeframe categories missing | Minor | Add urgency field to finding structure |
| 5 | "Likely cause" missing from finding structure | Minor | Add `cause_text` field to finding structure |
| 6 | Existing Supabase CLI inspection capabilities undocumented | Minor | Add section to `05_assessment_orchestration.md` |

## Numbering Impact

Inserting a new doc at `03_` requires renumbering the current `03_data_model.md` → `04_data_model.md` and cascading all subsequent numbers. The current numbering is:

```
01_methodology.md
02_assessment_model.md
03_data_model.md          → becomes 04_
04_context_ingestion.md   → becomes 05_
05_assessment_orchestration.md → becomes 06_
06_probe_system.md        → becomes 07_
07_cli_contract.md        → becomes 08_
08_rule_engine.md         → becomes 09_
09_scoring_model.md       → becomes 10_
10_probe_catalog.md       → becomes 11_
11_findings_catalog.md    → becomes 12_
12_roadmap.md             → becomes 13_
13_cross_assessment_model.md → becomes 14_
```

All cross-references between docs must be updated accordingly.

## Steps

### Step 1: Create `docs/03_human_checklist.md`

Create the missing Phase 1 deliverable: a standalone, human-usable assessment checklist. Content is derived from the conversation (lines ~369–525) and should be organized into sections A–J:

- **A. Context and objectives** — What is the database for? Top 3 business-critical apps? Workload type? Latency/availability expectations? Recent incidents? Primary pain?
- **B. Platform and topology** — PG version, managed vs self-hosted, HA/failover architecture, replicas and replication mode, backup tooling and restore validation cadence, monitoring stack
- **C. Reliability and recoverability** — Backups succeeding? Restores tested recently? Replication lag bounded? WAL generation/retention under control? Crash risk or storage exhaustion signs? Long transactions preventing cleanup?
- **D. Performance and workload** — Top queries by total time? By mean latency? By call volume? Evidence of temp file spill? Evidence of lock waits? Degradation periodic or continuous?
- **E. Storage and maintenance** — Largest tables/indexes, suspected bloat, dead tuple accumulation, autovacuum effectiveness, analyze freshness, zero/low-usage indexes, missing/duplicated indexes
- **F. Connections and concurrency** — Peak connections vs configured max, connection pooling present?, idle-in-transaction sessions?, lock trees/blocking chains?, prepared xacts/abandoned sessions?, replica conflicts?
- **G. Capacity and cost** — Data growth rate, WAL growth rate, CPU headroom, memory pressure indicators, I/O saturation, storage runway, overprovisioning/underprovisioning signals
- **H. Configuration hygiene** — 13 specific settings: `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`, `max_connections`, `random_page_cost`, `checkpoint_timeout`, `max_wal_size`, `autovacuum_*`, `log_min_duration_statement`, `track_io_timing`, `shared_preload_libraries`, `pg_stat_statements` enabled
- **I. Security and operational hygiene** — Superuser sprawl, unused roles, network exposure, SSL enforced?, extensions inventory, risky settings, logging sufficient for diagnosis?
- **J. Output** — Top risks, score by domain, recommended remediations, quick wins, strategic recommendations

Add a Supabase-specific addendum with platform-specific questions (RLS policies, Realtime usage, Auth provider, Storage usage, pgvector, pg_cron).

### Step 2: Renumber all docs `03_` through `13_`

Rename files:
- `03_data_model.md` → `04_data_model.md`
- `04_context_ingestion.md` → `05_context_ingestion.md`
- `05_assessment_orchestration.md` → `06_assessment_orchestration.md`
- `06_probe_system.md` → `07_probe_system.md`
- `07_cli_contract.md` → `08_cli_contract.md`
- `08_rule_engine.md` → `09_rule_engine.md`
- `09_scoring_model.md` → `10_scoring_model.md`
- `10_probe_catalog.md` → `11_probe_catalog.md`
- `11_findings_catalog.md` → `12_findings_catalog.md`
- `12_roadmap.md` → `13_roadmap.md`
- `13_cross_assessment_model.md` → `14_cross_assessment_model.md`

### Step 3: Update all cross-references

Grep all docs and `docs/README.md` for references to renamed files (e.g., `03_data_model.md`, `09_scoring_model.md`) and update to new numbers. Also update `docs/README.md` reading order list.

### Step 4: Add security probe and finding (Gap #2)

**In `07_probe_system.md`** (formerly `06_`):
- Add `role_inventory` as a v1 baseline probe (not v1.1 optional). It was in the conversation's SQL pack (query 3.23) and covers: `rolname`, `rolsuper`, `rolcreaterole`, `rolcreatedb`, `rolreplication`, `rolcanlogin`, `rolvaliduntil`.
- Add candidate finding: `excessive_superuser_roles`
- Affected domains: `operational_hygiene`, `availability`

**In `09_rule_engine.md`** (formerly `08_`):
- Add rule `excessive_superuser_roles`: medium if > 2 superuser roles; low if > 1 (beyond the default `postgres` role). Confidence: high.

**In `12_findings_catalog.md`** (formerly `11_`):
- Add finding `excessive_superuser_roles` with severity gradation and score effects: `operational_hygiene -10`, `availability -4`.

### Step 5: Expand configuration hygiene coverage (Gap #3)

**In `07_probe_system.md`** and `11_probe_catalog.md`:
- Expand the `instance_metadata` probe to also collect: `random_page_cost`, `log_min_duration_statement`, `track_io_timing`, `shared_preload_libraries`.
- These are diagnostic quality signals: `track_io_timing = off` means I/O timing data is unavailable; `log_min_duration_statement = -1` means no slow query logging.

**In `09_rule_engine.md`**:
- Add rule `diagnostic_configuration_weak`: medium if `track_io_timing = off` AND `log_min_duration_statement = -1` AND `pg_stat_statements` absent; low if any one of these is suboptimal. This complements `diagnostic_visibility_limited`.

### Step 6: Add urgency/timeframe to finding structure (Gap #4)

**In `04_data_model.md`** (formerly `03_`):
- Add `urgency text` column to `assessment_findings` table. Allowed values: `immediate` (within 1 week), `short_term` (within 30 days), `structural` (within quarter).

**In `12_findings_catalog.md`** (formerly `11_`):
- Add an `urgency` field to each finding entry. Assign values:
  - `immediate`: `active_lock_blocking_detected` (critical), `replication_slot_inactive_or_lagging` (critical)
  - `short_term`: `long_running_transactions_detected`, `idle_in_transaction_sessions_detected`, `dead_tuple_accumulation_detected`, `stale_vacuum_or_analyze_detected`, `auth_table_bloat_detected`
  - `structural`: `potentially_unused_large_indexes`, `storage_concentration_risk`, `high_impact_query_total_time`, `diagnostic_visibility_limited`

**In `08_cli_contract.md`** (formerly `07_`):
- Add `urgency` to the finding payload example.

### Step 7: Add "likely cause" to finding structure (Gap #5)

**In `04_data_model.md`** (formerly `03_`):
- Add `cause_text text` column to `assessment_findings` table, between `impact_text` and `recommendation_text`.

**In `12_findings_catalog.md`** (formerly `11_`):
- Add a `cause` line to each finding. Examples:
  - `long_running_transactions_detected`: "Application transaction boundaries are too broad, or sessions are being abandoned without rollback."
  - `dead_tuple_accumulation_detected`: "Autovacuum cannot reclaim dead tuples because long-running transactions hold back the visibility horizon, or autovacuum settings are insufficient for write volume."
  - `high_latency_queries_detected`: "Missing indexes, suboptimal query plans, or lock contention causing queries to wait."

**In `08_cli_contract.md`** (formerly `07_`):
- Add `cause_text` to the finding payload example.

### Step 8: Document existing Supabase CLI inspection capabilities (Gap #6)

**In `06_assessment_orchestration.md`** (formerly `05_`):
- Add a section "Existing Supabase CLI Capabilities" noting that the `supabase` CLI already has a `db inspect` subcommand with early diagnostic queries. New pg-healthkit probes should be aware of these to avoid duplication and to identify which existing outputs can be reused as evidence sources.
- Note that the specific capabilities should be inventoried during implementation and that the CLI contract in `08_cli_contract.md` should accommodate importing existing inspection outputs as evidence.

### Step 9: Update `docs/README.md`

- Add `03_human_checklist.md` to the reading order with description: "standalone assessment checklist for Phase 1 (human-usable, no tooling required)"
- Update all doc numbers in the reading order

### Step 10: Verify completeness

- Re-read the conversation sections on the checklist (lines ~369–525), security (lines ~499–513), configuration (lines ~473–497), action plan timeframes (lines ~354–362), finding structure (lines ~339–353), and Supabase CLI (lines ~1617–1627)
- Confirm no remaining content from the conversation is missing from the docs

## Out of Scope

- **Actual SQL file changes** — Expanding probes means updating SQL files in `probes/`, but that is implementation work, not documentation
- **Code changes** — No Go, TypeScript, or other code is written in this plan
- **Contract file updates** — `contracts/probe_registry.yaml`, `contracts/rules.yaml` etc. may need updates to match doc changes, but those are implementation artifacts

## Commit Strategy

One commit per logical step, or group tightly related steps:
1. Steps 1–3: New checklist doc + renumber + cross-references
2. Steps 4–5: Security probe + config hygiene expansion
3. Steps 6–7: Finding structure additions (urgency + cause_text)
4. Steps 8–9: Supabase CLI capabilities + README update
5. Step 10: Final verification pass
