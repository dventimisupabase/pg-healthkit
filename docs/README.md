# Inception Documents

These documents define the methodology, models, and design intent for pg-healthkit. They are the shared foundation that both the CLI and Arena implementations build on.

## Reading Order

For a new contributor or agent, read in this order:

1. `01_methodology.md` — the conceptual framework (start here)
2. `02_assessment_model.md` — assessment as a first-class entity
3. `03_context_ingestion.md` — how non-SQL context enters the system
4. `03_data_model.md` — SQL schema for the assessment database
5. `04_assessment_orchestration.md` — the "arena" — workflow and system design
6. `04_probe_system.md` — probe model and catalog (CLI-focused)
7. `05_rule_engine.md` — rule design and threshold logic (Arena-focused)
8. `06_scoring_model.md` — domain scoring and persona weights (Arena-focused)
9. `08_probe_catalog.md` — detailed probe descriptions with interpretation
10. `09_findings_catalog.md` — findings with severity and score effects
11. `10_roadmap.md` — phased delivery plan
12. `11_cross_assessment_model.md` — cross-assessment benchmarking (future)

## Supporting Documents

- `IMPLEMENTATION_PLAN.md` — practical build order, CLI milestones, test strategy
- `sample_report_template.md` — canonical report format

## Shared Contracts (in `../contracts/`)

These define the boundary between CLI and Arena:

- `../contracts/cli_contract.md` — CLI commands and API endpoints
- `../contracts/probe_registry.yaml` — canonical payload contracts per probe
- `../contracts/rules.yaml` — machine-readable rule definitions
- `../contracts/rules.md` — rule evaluation semantics
- `../contracts/normalizer_spec.md` — normalization rules
- `../contracts/normalizer_interface_contract.md` — runner-to-normalizer boundary

## Archive

- `chatgpt-conversation.md` — the original brainstorming session that produced these docs
