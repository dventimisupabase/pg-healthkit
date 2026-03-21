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
