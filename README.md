# pg-healthkit

Probe-driven PostgreSQL health assessment framework with rule-based analysis and scoring.

*From raw database signals to actionable health insights.*

## What This Is

A structured methodology and implementation scaffold for evaluating PostgreSQL database health. Designed for managed service contexts (Supabase) but portable to any PostgreSQL environment.

The system follows a top-down approach:

```
Context (persona / objective / workload)
      ↓
Evidence (SQL probes + platform data + customer input)
      ↓
Interpretation (rules + cross-signal synthesis)
      ↓
Scores + Findings
      ↓
Report (persona-aware)
```

## What's In This Repo

### Methodology & Model
| Document | Purpose |
|----------|---------|
| `01_methodology.md` | 10-step assessment framework: personas, workload types, health domains, KPIs, diagnostics, scoring |
| `02_assessment_model.md` | Assessment as a first-class entity: lifecycle, capabilities, entity model, profiles |
| `03_context_ingestion.md` | How non-SQL context enters the system: provenance matrix, intake tracks, canonical input keys |
| `03_data_model.md` | Full SQL schema: 7 tables, enums, indexes, design rationale |
| `04_assessment_orchestration.md` | The "arena": workflow system, three-layer architecture, interface options |

### Probes & Evidence
| Document | Purpose |
|----------|---------|
| `04_probe_system.md` | Probe model, classification, 24 probes (15 generic + 9 Supabase), mapping matrices |
| `08_probe_catalog.md` | Human-readable probe catalog with interpretation guidance |
| `probe_registry.yaml` | Machine-readable payload contracts per probe |
| `normalizer_spec.md` | How raw SQL output is transformed into canonical payloads |
| `normalizer_interface_contract.md` | Boundary between SQL runner and normalizer |

### Rules & Findings
| Document | Purpose |
|----------|---------|
| `05_rule_engine.md` | Rule design: 24 rules (15 generic + 9 Supabase), threshold logic, workload sensitivity |
| `09_findings_catalog.md` | 24 findings with severity gradation, score effects, interpretation |
| `rules.yaml` | Machine-readable rule definitions (v1: 15 generic rules) |
| `rules.md` | Evaluation semantics: profiles, fact resolution, operators, scoring |

### Scoring & Reporting
| Document | Purpose |
|----------|---------|
| `06_scoring_model.md` | 7 domains, persona-specific weights, tier-aware thresholds, Supabase adjustments |
| `sample_report_template.md` | Canonical report format with Mustache-style placeholders |

### CLI & Integration
| Document | Purpose |
|----------|---------|
| `07_cli_contract.md` | 8 CLI commands with JSON payloads, API endpoints, state transitions |

### Planning & Process
| Document | Purpose |
|----------|---------|
| `10_roadmap.md` | 4-phase roadmap (manual → CLI → time-series → productization) + Supabase track |
| `11_cross_assessment_model.md` | Cross-assessment benchmarking, pattern detection, product feedback loops |
| `IMPLEMENTATION_PLAN.md` | Practical build order, CLI milestones, test strategy, repo layout |
| `CONTRIBUTING.md` | Contribution workflow, contract stability rules, review checklist |

## Key Concepts

**Personas:** DBA/SRE, App Developer, CTO/Eng Leadership — each with different objectives and risk sensitivity.

**Workload Types:** OLTP, OLAP, Hybrid, Queue/Event-driven, Vector/Embedding, Multi-tenant SaaS.

**Health Domains:** Availability, Performance, Concurrency, Storage, Efficiency, Cost, Operational Hygiene.

**Assessment Profiles:** `default`, `performance`, `reliability`, `cost_capacity`, `supabase_default`.

**Probes:** 24 SQL-based evidence collectors (15 generic PostgreSQL + 9 Supabase-specific including RLS indexing, Realtime slot health, Auth schema bloat, Storage objects, system schema maintenance).

**Findings:** 24 interpretive results with severity, confidence, and score effects.

## Supabase-Specific Features

The framework includes dedicated support for Supabase platform concerns:

- **RLS policy column indexing** — detects missing indexes on Row Level Security filter columns (the #1 Supabase-specific performance issue)
- **Realtime replication slot health** — detects WAL bloat from unconsumed logical replication slots
- **Auth schema health** — monitors vacuum and bloat on auth.users, auth.sessions, auth.refresh_tokens
- **Storage objects health** — detects soft-delete pressure and growth on storage.objects
- **System schema bloat** — monitors platform-managed schemas (auth, storage, realtime, extensions)
- **PgBouncer/Supavisor pool health** — detects pool mode misconfiguration and contention
- **Tier-aware scoring** — adjusts thresholds based on Supabase instance tier
- **Feature interaction awareness** — PostgREST + RLS, Realtime + writes, Auth + traffic

## How to Use This Repo

### For manual assessments (Phase 1)
Run the SQL probes directly via `psql` against a target database. Use the checklist in `01_methodology.md` and report template in `sample_report_template.md` to structure findings.

### For CLI development (Phase 2)
Use `probe_registry.yaml`, `rules.yaml`, and the normalizer contracts as the implementation specification. Follow the build order in `IMPLEMENTATION_PLAN.md`.

### For agentic development
Point the agent to `01_methodology.md` first, then `probe_registry.yaml` and `rules.yaml`. Ask for small, testable increments. See `CONTRIBUTING.md` for guidance.
