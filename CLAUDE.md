# pg-healthkit

This is a monorepo with two implementation islands and shared foundations.

## Repository Structure

```
pg-healthkit/
├── docs/          # Inception docs — methodology, models, catalogs, roadmap
├── contracts/     # Shared contracts — the seam between CLI and Arena
├── cli/           # Go CLI plugin — probe collection, normalization, upload
├── arena/         # Assessment application — Supabase backend, Next.js frontend
```

## Navigation Rules

- **Start in `docs/`** to understand the methodology and design intent
- **`contracts/`** defines the boundary between the two islands — both depend on contracts, never on each other
- **Work in `cli/`** when building probe execution, normalization, or evidence upload
- **Work in `arena/`** when building the assessment system, rule engine, scoring, reporting, or UI

## Key Files

- `docs/01_methodology.md` — start here for the conceptual framework
- `contracts/probe_registry.yaml` — canonical payload contracts per probe
- `contracts/rules.yaml` — machine-readable rule definitions
- `contracts/cli_contract.md` — the API contract between CLI and Arena

## When Working on CLI (`cli/`)

Read these first:
1. `docs/04_probe_system.md` — probe model and catalog
2. `contracts/probe_registry.yaml` — what payloads to produce
3. `contracts/normalizer_spec.md` — how to normalize raw SQL output
4. `contracts/normalizer_interface_contract.md` — boundary between runner and normalizer
5. `contracts/cli_contract.md` — CLI commands and JSON payloads

The CLI's job is to collect evidence reliably. It does not interpret, score, or report.

## When Working on Arena (`arena/`)

Read these first:
1. `docs/03_data_model.md` — SQL schema for the assessment database
2. `docs/04_assessment_orchestration.md` — workflow and system design
3. `docs/05_rule_engine.md` — how rules produce findings
4. `docs/06_scoring_model.md` — domain scoring and persona weights
5. `contracts/rules.yaml` — machine-readable rule definitions
6. `contracts/cli_contract.md` — API endpoints the CLI calls

The Arena's job is to store assessments, evaluate rules, compute scores, and produce reports.

## Principles

- Contracts are the source of truth for the boundary between CLI and Arena
- Probes collect evidence; rules interpret evidence; scores summarize; reports render
- Do not blur these layers
- Prefer boring, explicit code over clever abstractions
- Test against fixtures derived from contracts
