# Residuals

Issues identified by `/grok` that require human judgment to resolve. Items are never automatically removed — manage this file manually.

---

## Contradiction: active_lock_blocking_detected missing critical case in rules.yaml

- **Found in**: `contracts/rules.yaml` (rule `active_lock_blocking_detected`), `docs/09_rule_engine.md` (section "active_lock_blocking_detected"), `docs/12_findings_catalog.md` (finding #3)
- **Problem**: Both `09_rule_engine.md` and `12_findings_catalog.md` define a "critical" severity case for `active_lock_blocking_detected` when "Blockers include DDL or very old xact." However, `rules.yaml` only implements two cases (high: blocking_pairs > 3, medium: blocking_pairs > 0) and has no critical case. Implementing the critical case requires defining what "DDL" and "very old xact" mean in terms of fact paths and thresholds against the `lock_blocking_chains` probe payload, which may require changes to the probe's summary fields.
- **Why it needs human input**: The critical case depends on detecting DDL lock types and transaction age within blocking chains, which requires design decisions about what payload fields to expose and what thresholds constitute "very old."
- **Detected**: 2026-03-20

## Gap: sample_report_template.md missing Action Plan and Domain Score Detail sections

- **Found in**: `docs/sample_report_template.md`, `docs/16_report_template.md` (sections 4 "Action Plan" and 5 "Domain Score Detail")
- **Problem**: `16_report_template.md` specifies 9 report sections, including "Action Plan" (section 4, a prioritized remediation plan by urgency) and "Domain Score Detail" (section 5, per-domain score breakdown with contributing findings). The actual `sample_report_template.md` only has 7 sections and omits both of these. Adding them requires designing the template syntax for urgency grouping and score-to-finding attribution.
- **Why it needs human input**: The template syntax for grouping findings by urgency and rendering per-domain score breakdowns with contributing deltas requires design decisions about data shape and presentation that are not fully specified.
- **Detected**: 2026-03-20

## Inconsistency: diagnostic_configuration_weak rule missing pg_stat_statements condition in medium case

- **Found in**: `contracts/rules.yaml` (rule `diagnostic_configuration_weak`), `docs/12_findings_catalog.md` (finding #16)
- **Problem**: The findings catalog defines the medium case as requiring ALL three conditions: `track_io_timing = off AND log_min_duration_statement = -1 AND pg_stat_statements absent`. But `rules.yaml` medium case only checks two conditions (`track_io_timing = off AND log_min_duration_statement = -1`), omitting the `pg_stat_statements` check. Adding the third condition requires resolving a cross-probe fact (pg_stat_statements presence is in `extensions_inventory`, not `instance_metadata`), which means adding `extensions_inventory` to the rule's `required_probes`. This changes rule evaluation semantics (the rule would be skipped if `extensions_inventory` didn't run).
- **Why it needs human input**: Adding a cross-probe dependency changes skip semantics and may not be desirable. The human needs to decide whether the medium case should require all three conditions or whether the two-condition version in rules.yaml is the intended simplification.
- **Detected**: 2026-03-20

## Gap: Methodology scoring weights disagree with scoring model default weights

- **Found in**: `docs/01_methodology.md` (section 7 "Scoring Model"), `docs/10_scoring_model.md` (section "Default Profile")
- **Problem**: The methodology doc shows DBA/SRE weights as: Availability 25%, Concurrency 20%, Storage 15%, Performance 15%, Operational Hygiene 10%, Efficiency 10%, Cost 5%. The scoring model doc has the same for the `reliability` profile. However, the methodology doc does not show the `default` profile weights. The default profile in `10_scoring_model.md` and the score payload examples in `04_data_model.md` and `08_cli_contract.md` use different weight sets (e.g., data model example uses availability: 0.2, performance: 0.2, concurrency: 0.15, storage: 0.15, operational_hygiene: 0.1, efficiency: 0.1, cost: 0.1). These all match the default profile in `10_scoring_model.md`, so this is consistent. But the methodology doc's example weights only show the reliability profile, which could mislead readers into thinking those are the default weights.
- **Why it needs human input**: This is a documentation framing choice. The methodology doc could add the default weights or clarify that the example shown is the reliability profile. Either approach is valid.
- **Detected**: 2026-03-20

## Gap: probes/README.md profile table incomplete for performance, reliability, and cost_capacity profiles

- **Found in**: `probes/README.md` (section "Profile-Based Probe Selection")
- **Problem**: The profile selection table does not include probe 50 (role_inventory) in any profile despite it being in the `default` and `reliability` profiles per the registry. The `performance` profile row does not match the registry (e.g., missing lock_blocking_chains 13). The `reliability` profile row is also incomplete. The `cost_capacity` profile includes probe 40-41 but the registry does not include `replication_health` in cost_capacity. The table appears to be a rough approximation that has drifted from `probe_registry.yaml`.
- **Why it needs human input**: Fully reconciling this table requires deciding on the level of detail appropriate for the probes README (it may be intentionally simplified), and whether to maintain it as a duplicate of the registry or remove it in favor of pointing to the registry.
- **Detected**: 2026-03-20
