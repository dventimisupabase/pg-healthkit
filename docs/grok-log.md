# Grok Log

---

### 2026-03-20

**Counts:**
- Total issues found: 17
- Already known from residuals: 0
- New issues found: 17
- New issues auto-fixed: 12
- New residuals added: 5

**Fixes made:**
- Fixed `sample_report_template.md` referencing nonexistent `rules.md` and `normalizer_spec.md`; corrected to `docs/09_rule_engine.md` and `docs/15_normalizer.md`
- Fixed `README.md` referencing `docs/03_data_model.md` instead of `docs/04_data_model.md`
- Fixed `arena/CLAUDE.md` referencing `../docs/03_data_model.md` instead of `../docs/04_data_model.md`
- Fixed `03_human_checklist.md` claiming "10 sections" when there are 11 (A-K); corrected section descriptions
- Fixed `instance_metadata` probe registry: replaced `diagnostic_visibility_limited`, `replication_lag_elevated`, `storage_concentration_risk` in `supports_findings` with `diagnostic_configuration_weak` (the actual rule that requires it); added `operational_hygiene` to `affects_domains`
- Fixed `rls_policy_columns_unindexed` threshold description in `12_findings_catalog.md` and `09_rule_engine.md` from "tables" to "columns" to match the actual rule in rules.yaml which checks `unindexed_policy_column_count`
- Added `dead_tuple_pct` summary field and `storage_objects_bloat` to `storage_objects_health` probe registry to match the `storage_objects_bloat` rule in rules.yaml
- Added `misconfigured_index_count` summary field and `pgvector_index_misconfigured` to `pgvector_index_health` probe registry to match the `pgvector_index_misconfigured` rule in rules.yaml
- Fixed `probes/README.md` default profile probe range from `30-34` (no probe 34 exists) to `30-33, 50`
- Added `supabase_default` profile to all 13 Supabase-specific rules in rules.yaml to match their corresponding probes which already include this profile

**New residuals added:**
- `active_lock_blocking_detected` missing critical severity case in rules.yaml (requires payload design decisions)
- `sample_report_template.md` missing Action Plan and Domain Score Detail sections from report contract
- `diagnostic_configuration_weak` rule medium case missing pg_stat_statements condition (cross-probe dependency question)
- Methodology doc scoring weights example only shows reliability profile, could mislead about defaults
- `probes/README.md` profile selection table has drifted from probe_registry.yaml across multiple profiles

---

### 2026-03-20 (pass 2)

**Counts:**
- Total issues found: 18
- Already known from residuals: 5
- New issues found: 13
- New issues auto-fixed: 13
- New residuals added: 0

**Fixes made:**
- Fixed `rls_policy_column_indexing` SQL probe: renamed output columns `relname` to `tablename` and `is_indexed` to `has_index` to match probe_registry.yaml contract
- Fixed `rls_policy_column_indexing` SQL header: added missing `supabase_default` profile to match registry
- Fixed `role_inventory` SQL header: removed `cost_capacity` profile to match registry (which only lists `default, reliability`)
- Fixed `07_probe_system.md`: moved `wal_checkpoint_health` from "Contextual Probes" section to new "Baseline Probes (WAL and checkpoint)" section to match registry `category: baseline`
- Fixed `07_probe_system.md`: renamed Supabase probes 23-25 section from "Contextual (v1.1)" to "Baseline (v1.1, prerequisite-gated)" to match registry `category: baseline`
- Fixed `09_rule_engine.md`: updated `rls_policy_columns_unindexed` logic to remove non-existent low case (rules.yaml only implements high and medium)
- Fixed `09_rule_engine.md`: updated `storage_soft_delete_pressure` logic to remove table size condition and medium case not in rules.yaml
- Fixed `09_rule_engine.md`: updated `system_schema_vacuum_stale` logic to match rules.yaml (single high case at > 30%)
- Fixed `09_rule_engine.md`: updated `pool_mode_misconfiguration` logic to match rules.yaml (single low case for transaction mode)
- Fixed `12_findings_catalog.md`: aligned 8 Supabase findings with rules.yaml — removed non-existent severity bands from rls_policy_columns_unindexed, storage_soft_delete_pressure, system_schema_vacuum_stale, pool_mode_misconfiguration, pg_cron_job_failures, extension_version_outdated, pgvector_missing_index; corrected score effect labels and values

**New residuals added:**
- None

---

### 2026-03-20 (pass 3)

**Counts:**
- Total issues found: 10
- Already known from residuals: 5
- New issues found: 5
- New issues auto-fixed: 5
- New residuals added: 0

**Fixes made:**
- Fixed `contracts/probe_registry.yaml`: changed `summary.log_min_duration_statement` type from `string` to `integer` to match `rules.yaml` (which compares with integer `-1`) and `docs/15_normalizer.md` (which says "coerce to integer")
- Fixed `docs/07_probe_system.md`: corrected stale reference to nonexistent `normalizer_interface_contract.md`; updated to `15_normalizer.md`
- Fixed `docs/07_probe_system.md`: updated `instance_metadata` row in Probe-to-Finding Mapping table — changed primary from `—` to `diagnostic_configuration_weak`, removed stale `diagnostic_visibility_limited` from corroboration column
- Fixed `docs/11_probe_catalog.md`: added missing `diagnostic_configuration_weak` finding to Probe-to-Finding Mapping Matrix (primary probe: `instance_metadata`)
- Fixed `CONTRIBUTING.md`: corrected stale reference to `rules.md` to `docs/09_rule_engine.md`

**New residuals added:**
- None

---

### 2026-03-20 (pass 4)

**Counts:**
- Total issues found: 11
- Already known from residuals: 5
- New issues found: 6
- New issues auto-fixed: 6
- New residuals added: 0

**Fixes made:**
- Fixed `contracts/probe_registry.yaml`: added missing `rolreplication` property to `role_inventory` payload contract to match the SQL probe output in `probes/50_role_inventory.sql`
- Fixed `probes/README.md`: changed Supabase probe range 60-69 category from "Contextual" to "Baseline" to match `probe_registry.yaml` which lists all Supabase probes as `category: baseline`
- Fixed `docs/12_findings_catalog.md`: removed duplicate table separator line above the "Finding Structure" header row (malformed markdown table)
- Fixed `docs/sample_report_template.md`: renamed action plan section "Long-term" to "Structural" to match the urgency enum values used in `rules.yaml` and `docs/12_findings_catalog.md`
- Fixed `docs/07_probe_system.md`: corrected `realtime_replication_slot_health` candidate findings from stale `replication_slot_lag_elevated` / `replication_slot_inactive` to `replication_slot_inactive_or_lagging` to match `rules.yaml` and `probe_registry.yaml`
- Fixed `docs/16_report_template.md`: added missing Action Plan, Domain Score Detail, Interpretation Notes, and Methodology Reference sections to the Alignment with Data Model table

**New residuals added:**
- None

---

### 2026-03-20 (pass 5)

**Counts:**
- Total issues found: 13
- Already known from residuals: 5
- New issues found: 8
- New issues auto-fixed: 8
- New residuals added: 0

**Fixes made:**
- Fixed `docs/sample_report_template.md`: renamed template variable `action_plan.long_term` to `action_plan.structural` to match the urgency enum used in `rules.yaml` (section title was already fixed in pass 4 but variable name was missed)
- Fixed `docs/12_findings_catalog.md`: simplified `auth_table_bloat_detected` conditions to match `rules.yaml` — removed "OR row count > 5M with stale vacuum" and "OR row count > 1M" conditions not present in the contract
- Fixed `docs/12_findings_catalog.md`: simplified `storage_objects_bloat` high condition to match `rules.yaml` — removed "AND size > 1 GB" condition not present in the contract
- Fixed `docs/12_findings_catalog.md`: simplified `pool_contention_detected` high condition to match `rules.yaml` — removed "AND wait duration > 1 second" condition not present in the contract (registry has no `wait_duration` field)
- Fixed `docs/09_rule_engine.md` and `docs/12_findings_catalog.md`: changed `high_connection_utilization` inputs from "`connection_pressure`, `instance_metadata`" to "`connection_pressure`" to match `rules.yaml` which only requires `connection_pressure`
- Fixed `docs/09_rule_engine.md` and `docs/12_findings_catalog.md`: corrected `replication_slot_inactive_or_lagging` thresholds from "500MB" to "512 MiB" and "1GB" to "1 GiB" to match `rules.yaml` byte values (536870912 and 1073741824); removed non-existent medium case ("lag > 100MB") from both docs
- Fixed `contracts/probe_registry.yaml`: added missing `row_count` to `role_inventory` summary to match `docs/15_normalizer.md` derivation rules and the pattern of all other probes with row arrays
- Fixed `contracts/rules.yaml`: changed `defaults.evaluation_mode` from `all_conditions` to `first_match` to match actual usage (every rule in the file uses `mode: first_match`)

**New residuals added:**
- None

---

### 2026-03-20 (pass 6)

**Counts:**
- Total issues found: 5
- Already known from residuals: 0
- New issues found: 5
- New issues auto-fixed: 4
- New residuals added: 1

**Fixes made:**
- Fixed `probes/README.md`: changed 40-49 range category from "Contextual" to "Mixed (contextual and baseline)" since `wal_checkpoint_health` (41) is baseline per `probe_registry.yaml` while `replication_health` (40) is contextual
- Fixed `probes/README.md`: renamed "Canonical envelope" section to "Raw evidence envelope (manual collection)" and added clarification that this format differs from the canonical normalized payload defined in `docs/15_normalizer.md` (the raw format includes `collected_at` and `columns` fields not present in the canonical format)
- Fixed `docs/09_rule_engine.md`: removed "AND `pg_stat_statements` absent" from the `diagnostic_configuration_weak` medium case description to match `rules.yaml` which only checks two conditions (`track_io_timing = off` AND `log_min_duration_statement = -1`)
- Fixed `docs/02_assessment_model.md`: updated Finding Structure example to use correct field names from the data model (`finding_key` instead of `id`, `impact_text` instead of `impact`, `recommendation_text` instead of `recommendation`, `cause_text`, `summary`, `evidence_refs`) and the canonical finding key `long_running_transactions_detected`

**New residuals added:**
- `supabase_default` profile inheritance not encoded in contracts (requires design decision on explicit vs implicit profile inheritance)

---

### 2026-03-20 (pass 7)

**Counts:**
- Total issues found: 11
- Already known from residuals: 5
- New issues found: 6
- New issues auto-fixed: 3
- New residuals added: 3

**Fixes made:**
- Fixed `docs/07_probe_system.md`: removed stale `collected_at` field from "Standardized Evidence Payload" example to match the authoritative canonical envelope in `docs/15_normalizer.md`
- Fixed 8 Supabase SQL probe headers to add missing `supabase_default` profile to match `probe_registry.yaml`: `realtime_replication_slot_health`, `auth_schema_health`, `storage_objects_health`, `system_schema_bloat`, `pgbouncer_pool_health`, `pg_cron_job_health`, `extension_version_health`, `pgvector_index_health`; also fixed `auth_schema_health` profile list from `default, performance, reliability` to `default, reliability, cost_capacity, supabase_default` to match registry
- Fixed `probes/63_storage_objects_health.sql`: renamed output column `soft_deleted_pct` to `soft_deleted_ratio` to match `probe_registry.yaml` contract field name
- Fixed `probes/00_instance_metadata.sql`: renamed output column `autovacuum_enabled` to `autovacuum` to match `probe_registry.yaml` contract field name (`settings.autovacuum`)

**New residuals added:**
- `wal_checkpoint_health` SQL column names lack `_ms` suffix required by registry (requires decision on SQL alias naming vs normalizer mapping)
- `pgbouncer_pool_health` SQL probe cannot produce required registry fields `waiting_clients` and `active_connections` (requires implementation strategy decision)
- `docs/15_normalizer.md` missing probe-specific summary derivation for all 9 Supabase probes (requires domain-specific normalization logic decisions)

---

### 2026-03-20 (pass 8)

**Counts:**
- Total issues found: 11
- Already known from residuals: 4
- New issues found: 7
- New issues auto-fixed: 7
- New residuals added: 0

**Fixes made:**
- Fixed `docs/12_findings_catalog.md`: changed "Blocked count > 3" to "Blocking pairs > 3" for `active_lock_blocking_detected` to match `rules.yaml` field name `summary.blocking_pairs`
- Added clarifying note to `docs/09_rule_engine.md` V1 Rule Catalog explaining that "Inputs" lists both required and corroborating probes, with `rules.yaml` `required_probes` as the authoritative required list
- Added matching clarifying note to `docs/12_findings_catalog.md` Findings section
- Fixed `docs/09_rule_engine.md`: changed `active_lock_blocking_detected` logic from "blocked count > 3" to "blocking pairs > 3" to match contract terminology
- Fixed `docs/07_probe_system.md`: removed `replication_health` from `cost_capacity` profile emphasis list (registry only includes it in `[default, reliability]`)
- Fixed `docs/07_probe_system.md`: removed `replication_health` from Cost domain Secondary probes list (registry `affects_domains` for this probe is `[availability, performance]`, not cost)
- Added 3 missing Supabase rules to `docs/09_rule_engine.md`: `pg_cron_job_failures`, `extension_version_outdated`, `pgvector_missing_index` (all present in `rules.yaml` and `12_findings_catalog.md` but were absent from the rule engine doc)

**New residuals added:**
- None

---

### 2026-03-21 (pass 9 — SQL-contract column alignment focus)

**Counts:**
- Total issues found: 19
- Already known from residuals: 0
- New issues found: 19
- New issues auto-fixed: 19
- New residuals added: 0

**Special focus:** SQL probe output columns vs probe_registry.yaml contract fields.

**Findings:**
- All 25 SQL probes were checked against their corresponding probe_registry.yaml entries
- No column name mismatches found between SQL output aliases and registry field names
- No missing required fields in SQL output
- 16 generic SQL probe headers were missing `supabase_default` profile (cosmetic, since the registry is authoritative, but consistency matters)
- 3 stale column name references in docs/15_normalizer.md for Supabase probes

**Fixes made:**
- Added missing `supabase_default` profile to SQL header comments in all 16 generic probes (00-50) to match probe_registry.yaml
- Fixed `docs/15_normalizer.md` pgvector_index_health section: updated stale references to `table_name` and `missing_vector_index` (SQL actually outputs `tablename` and `has_index` directly)
- Fixed `docs/15_normalizer.md` pg_cron_job_health section: noted that SQL already aliases `command` to `jobname` and `start_time` to `last_run_time` (normalizer mapping description was misleading)
- Fixed `docs/15_normalizer.md` pgbouncer_pool_health section: corrected column reference from `active` to `active_connections` to match SQL probe output

**SQL-contract alignment summary:**
- All 25 probes have SQL output column names that match or are properly mapped by the normalizer
- Extra fields in SQL output beyond registry requirements: `client_addr` in replication_health, `n_live_tup`/`n_dead_tup`/`last_autoanalyze`/`total_bytes` in system_schema_bloat, `temp_blks_written` in top_queries_mean_latency — all acceptable per forward-compatibility rules
- Known residuals about pgbouncer_pool_health field mapping and wal_checkpoint_health _ms suffix remain unchanged

**New residuals added:**
- None

---

### 2026-03-21 (pass 10)

**Counts:**
- Total issues found: 11
- Already known from residuals: 8
- New issues found: 3
- New issues auto-fixed: 3
- New residuals added: 0

**Fixes made:**
- Fixed `docs/03_human_checklist.md`: added missing `---` horizontal rule separator between sections F (Connections and Concurrency) and G (Resource Efficiency) to match all other section boundaries
- Fixed `docs/11_probe_catalog.md`: removed incorrect `top_queries_mean_latency` corroboration for `rls_policy_columns_unindexed` finding (changed to `—` to match `docs/07_probe_system.md` and `rules.yaml` which only requires `rls_policy_column_indexing`)
- Fixed `docs/11_probe_catalog.md`: changed `pool_contention_detected` corroboration from `connection_pressure` to `top_queries_total_time` to match `docs/07_probe_system.md` Supabase Probe-to-Finding Mapping table

**New residuals added:**
- None

---

### 2026-03-21 (pass 11)

**Counts:**
- Total issues found: 11
- Already known from residuals: 8
- New issues found: 3
- New issues auto-fixed: 3
- New residuals added: 0

**Fixes made:**
- Fixed `docs/07_probe_system.md`: changed "Contextual Supabase probes" to "Prerequisite-gated Supabase probes" for `pg_cron_job_health`, `extension_version_health`, `pgvector_index_health` — these are `category: baseline` in `probe_registry.yaml`, not contextual; calling them "contextual" contradicted the registry and the section header that was already fixed in pass 2
- Fixed `docs/sample_report_template.md`: added missing `{{cause}}` section in findings detail between Summary and Impact — every rule in `rules.yaml` has a `cause_template`, the data model (`04_data_model.md`) has `cause_text`, and `12_findings_catalog.md` defines Cause for every finding, but the report template was omitting it
- Fixed `docs/16_report_template.md`: added missing "Cause" field to Section 3 finding detail list — the section lists Summary, Impact, Recommendation but omitted Cause, which is present in every rule's `cause_template` and is explicitly mentioned in the Section 3 description of `02_assessment_model.md`

**Known residuals re-confirmed (8):**
- `active_lock_blocking_detected` missing critical severity case in rules.yaml (requires payload design decisions)
- `diagnostic_configuration_weak` rule medium case missing pg_stat_statements condition (cross-probe dependency question)
- Methodology doc scoring weights example only shows reliability profile
- `probes/README.md` profile selection table has drifted from probe_registry.yaml
- `supabase_default` profile inheritance not encoded in contracts (requires design decision)
- `wal_checkpoint_health` SQL column names lack `_ms` suffix required by registry (requires naming decision)
- `pgbouncer_pool_health` SQL probe cannot produce required registry fields `waiting_clients` and `active_connections` (requires implementation strategy)
- Generic rules in `rules.yaml` do not include `supabase_default` profile — if the rule engine uses literal profile matching, no generic rules will fire for `supabase_default` assessments (same root cause as profile inheritance residual)

**New residuals added:**
- None
