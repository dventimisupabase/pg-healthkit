# Arena Island — Assessment Application

## What This Is

A web application for managing PostgreSQL health assessments. Supabase as the backend (Postgres + Edge Functions + Auth), Next.js as the frontend. The "laboratory" where evidence is stored, rules are evaluated, scores are computed, reports are generated, and workflows are managed.

## Architecture

```
Arena
├── Supabase Backend
│   ├── Migrations     — assessment schema (from docs/03_data_model.md)
│   ├── Edge Functions — rule engine, scoring, report generation
│   └── Auth           — operator authentication
├── Next.js Frontend
│   ├── Assessment list and detail views
│   ├── Context input forms (customer intake)
│   ├── Findings and score display
│   └── Report rendering
└── API Layer
    └── Endpoints defined in contracts/cli_contract.md
```

## Key Contracts (read these first)

- `../contracts/cli_contract.md` — API endpoints the CLI calls (the Arena implements these)
- `../contracts/rules.yaml` — machine-readable rule definitions to implement
- `../contracts/rules.md` — evaluation semantics (profiles, fact resolution, operators, scoring)
- `../contracts/probe_registry.yaml` — payload shapes the Arena receives and validates

## Design Docs

- `../docs/03_data_model.md` — full SQL schema with 7 tables, enums, indexes
- `../docs/04_assessment_orchestration.md` — workflow, three-layer architecture, interface options
- `../docs/03_context_ingestion.md` — how non-SQL context enters the system
- `../docs/05_rule_engine.md` — rule design, 24 rules with threshold logic
- `../docs/06_scoring_model.md` — 7 domains, persona weights, Supabase adjustments
- `../docs/09_findings_catalog.md` — 24 findings with severity and score effects
- `../docs/sample_report_template.md` — canonical report format
- `../docs/11_cross_assessment_model.md` — cross-assessment benchmarking (future)

## What the Arena Does

1. **Store assessments** — create, update lifecycle state, persist all data
2. **Accept evidence** — receive canonical payloads from CLI, validate, store
3. **Collect context** — intake forms for customer-derived inputs (persona, objectives, workload)
4. **Auto-populate platform context** — fetch Supabase platform metadata (tier, region, features)
5. **Evaluate rules** — load evidence, apply rules from `rules.yaml`, produce findings
6. **Compute scores** — apply score deltas, weight by profile, produce per-domain and overall scores
7. **Generate reports** — render findings and scores into markdown/HTML using the report template
8. **Manage workflow** — track assessment lifecycle (draft → intake → evidence → analysis → review → completed)

## What the Arena Does NOT Do

- Execute SQL probes against customer databases (that's the CLI's job)
- Normalize raw probe output (that's the CLI's job)

## Schema

The first migration should create the schema from `../docs/03_data_model.md`:
- `assessments` — the lifecycle object
- `assessment_inputs` — key/value inputs with provenance
- `assessment_evidence` — raw probe payloads (JSONB)
- `assessment_findings` — rule-derived findings
- `assessment_scores` — per-domain and overall scores
- `assessment_reports` — generated report artifacts
- `assessment_events` — audit trail

## Rule Engine

Implement the evaluation semantics from `../contracts/rules.md`:
- Load rules from `../contracts/rules.yaml`
- Filter by assessment profile
- Check required probes
- Resolve fact paths into normalized payloads
- Evaluate conditions (first-match)
- Render findings from templates
- Accumulate score deltas

Can be implemented as Supabase Edge Functions or as a separate service.

## Build Order

1. Schema migration (create tables from `docs/03_data_model.md`)
2. API endpoints for assessment CRUD and evidence upload
3. Rule engine (load rules, evaluate, produce findings)
4. Score computation
5. Report generation (markdown first)
6. Next.js UI (assessment list, detail, findings, scores)
7. Context intake forms
8. Workflow management

## Testing

- Rule evaluation: fixture-driven tests with canonical payloads → expected findings
- Scoring: verify delta accumulation and clamping
- API: integration tests for each endpoint
- Report: snapshot tests comparing generated output to expected markdown
