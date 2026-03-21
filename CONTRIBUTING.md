# Contributing

This repository is intended to support iterative development of a PostgreSQL health assessment framework, probe system, rule engine, and CLI integration path.

The primary goal is consistency of contracts, not rapid novelty. Contributors should prefer explicitness, stable field names, and testable behavior over abstraction or cleverness.

## Scope

The repository currently contains:

- methodology documents (personas, workload classification, health domains)
- assessment model and lifecycle (including data model schema)
- context ingestion model (evidence provenance, two-track intake)
- assessment orchestration (workflow, arena design, three-layer architecture)
- SQL probe definitions (25 probes: 16 generic + 9 Supabase-specific)
- machine-readable probe registry (`probe_registry.yaml`)
- machine-readable rule catalog (`rules.yaml`)
- findings catalog (30 findings with severity gradation and score effects: 17 generic + 13 Supabase-specific)
- scoring model (7 domains, persona-weighted, tier-aware)
- prose descriptions of evaluation and normalization semantics
- normalizer contracts for converting SQL output into canonical payloads
- CLI contract (8 commands with JSON payloads and API endpoints)
- Supabase-specific layers (RLS indexing, Auth schema, Realtime slots, Storage, system schemas, PgBouncer)

Contributions should preserve coherence across these layers.

## Core Principles

When contributing, optimize for:

- stable contracts
- explainable findings
- deterministic normalization
- reproducible rule evaluation
- clear separation of concerns

In practice this means:

- probes collect evidence
- normalizers shape evidence
- rules interpret evidence
- scores summarize rule effects
- reports render outputs for humans

Do not blur these layers without a strong reason.

## Repository Expectations

Any change to one layer may require updates in adjacent layers.

Examples:

- adding or renaming a normalized field usually requires updates to `probe_registry.yaml`, `rules.yaml`, and any relevant prose docs
- adding a new probe usually requires SQL, registry metadata, normalization guidance, and tests
- adding a new rule usually requires both `rules.yaml` and supporting prose in `docs/09_rule_engine.md`
- changing units, thresholds, or summary field semantics requires explicit documentation

## Recommended Workflow

Use this workflow for substantive changes:

1. Read the high-level docs first
2. Identify the layer being changed
3. Make the minimal contract change needed
4. Update machine-readable files first
5. Update prose docs to match
6. Add or update tests
7. Validate that examples still make sense end-to-end

## File Roles

These files are the key sources of truth:

**Inception docs (`docs/`):**
- `docs/01_methodology.md` — conceptual framework (personas, workloads, domains, diagnostics)
- `docs/02_assessment_model.md` — lifecycle and object model
- `docs/03_human_checklist.md` — standalone assessment checklist for Phase 1
- `docs/04_data_model.md` — SQL schema for the assessment system of record
- `docs/05_context_ingestion.md` — how non-SQL context enters the system
- `docs/06_assessment_orchestration.md` — workflow system and arena design
- `docs/07_probe_system.md` — probe model, classification, and mapping matrices
- `docs/08_cli_contract.md` — CLI integration contract, commands, and API endpoints
- `docs/09_rule_engine.md` — rule design, evaluation semantics, and threshold logic
- `docs/10_scoring_model.md` — domain scoring, persona weights, Supabase adjustments
- `docs/11_probe_catalog.md` — human-readable probe catalog with interpretation guidance
- `docs/12_findings_catalog.md` — findings with severity gradation and score effects
- `docs/13_roadmap.md` — phased delivery plan
- `docs/14_cross_assessment_model.md` — cross-assessment benchmarking (future)
- `docs/15_normalizer.md` — normalization model and transformation pipeline
- `docs/16_report_template.md` — report output contract and presentation semantics

**Shared contracts (`contracts/`):**
- `docs/08_cli_contract.md` — operator-facing command model and API endpoints
- `contracts/rules.yaml` — machine-readable evaluation logic
- `docs/09_rule_engine.md` — human explanation of rule semantics
- `contracts/probe_registry.yaml` — canonical payload contracts per probe
- `docs/15_normalizer.md` — normalization rules, interface boundary, and probe-specific summary derivation

Avoid editing one of these in isolation if the change crosses boundaries.

## Adding a New Probe

When adding a probe:

1. Add the SQL file under `probes/`
2. Add a probe entry to `contracts/probe_registry.yaml`
3. Define the normalized payload contract
4. Define summary fields if the rule engine will depend on them
5. Update methodology docs only if the probe materially changes the model
6. Add example raw input and canonical output fixtures
7. Add tests for:
   - success with representative rows
   - success with zero rows
   - skipped or failed execution

Questions to answer before merging:
- What finding(s) does this probe support?
- Which score domains does it affect?
- Are the summary fields stable enough for rules?
- Is the probe profile-scoped correctly?
- If Supabase-specific: does it require system schema access? Is it included in the `supabase_default` profile?

## Adding a New Rule

When adding a rule:

1. Add the rule to `contracts/rules.yaml`
2. Add human-readable explanation to `docs/09_rule_engine.md` if semantics are new
3. Confirm the referenced probe fields exist in `contracts/probe_registry.yaml`
4. Add tests for:
   - matching case
   - no-match case
   - skipped due to missing required probe
5. Review severity, confidence, and score deltas for proportionality

Questions to answer before merging:
- Is the rule explainable to an operator?
- Does it depend on stable normalized fields?
- Is the rule severity workload-sensitive?
- Should it be profile-limited?

## Changing a Payload Contract

Changing normalized field names or units is a high-risk change.

Before making such a change:

- decide whether the change is truly necessary
- prefer additive changes over breaking changes
- update `contracts/probe_registry.yaml`
- update any affected rules
- update prose docs and examples
- consider versioning the contract if the change is breaking

Examples of breaking changes:
- renaming `summary.top_mean_exec_time_ms`
- changing bytes to human-readable strings
- changing seconds to interval text

## Documentation Expectations

Documentation should be operationally useful.

Prefer:
- precise language
- explicit field names
- concrete examples
- direct mapping between documents and implementation

Avoid:
- vague aspirational wording
- duplicated definitions that drift over time
- undocumented hidden assumptions

## Testing Expectations

A credible implementation should test at least three layers:

### Probe execution
- SQL runs or is skipped correctly
- raw result shape is captured faithfully

### Normalization
- raw tabular output is converted into canonical payloads
- types and summary fields match the registry

### Rule evaluation
- canonical payloads produce the expected findings and score deltas
- skipped probes do not create false negatives

At minimum, each probe and rule should have representative fixture-driven tests.

## Backward Compatibility

Try to preserve backward compatibility for:

- probe names
- rule IDs
- normalized field names
- score domain names

These identifiers become integration points for tooling, persistence, and reports.

## Review Checklist

Before proposing a change, verify:

- machine-readable and prose docs agree
- field names are consistent
- units are explicit and stable
- summary fields are deterministic
- thresholds are justified
- examples still parse and make sense
- the change does not smuggle business logic into the wrong layer

## Non-Goals

This repository does not currently aim to solve:

- advanced anomaly detection
- automated remediation
- fully dynamic scoring optimization
- generalized monitoring for all database engines

Keep contributions aligned with the current scope unless the repository direction explicitly changes.

## Practical Advice for Agentic Development

If using Codex or another agentic tool:

- point the agent to the methodology docs first
- then provide `contracts/probe_registry.yaml`, `contracts/rules.yaml`, and the normalizer docs
- ask for small, testable increments
- require the agent to preserve contract stability
- prefer generated code that is boring and explicit

The best first implementation is not the most sophisticated one. It is the one that can be validated end-to-end.
