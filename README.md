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

## Repository Structure

This is a monorepo with two implementation islands and shared foundations:

```
pg-healthkit/
├── docs/              # Inception docs — methodology, models, catalogs, roadmap
├── contracts/         # Shared contracts — the seam between CLI and Arena
├── cli/               # Go CLI plugin — probe collection, normalization, upload
├── arena/             # Assessment application — Supabase backend, Next.js frontend
├── CLAUDE.md          # Top-level agent guidance
├── CONTRIBUTING.md    # Contribution workflow and contract stability rules
└── README.md          # This file
```

### Two Islands

| Island | Purpose | Language/Stack | Key Docs |
|--------|---------|---------------|----------|
| **`cli/`** | Execute SQL probes, normalize payloads, upload evidence | Go | `docs/06_probe_system.md`, `docs/07_cli_contract.md`, `contracts/normalizer_spec.md` |
| **`arena/`** | Store assessments, evaluate rules, compute scores, generate reports, manage workflow | Supabase + Next.js | `docs/03_data_model.md`, `docs/08_rule_engine.md` |

The two islands depend on **`contracts/`**, never on each other directly.

### Shared Contracts

| Contract | Purpose |
|----------|---------|
| `contracts/cli_contract.md` | CLI commands, API endpoints, JSON payloads — the interface between CLI and Arena |
| `contracts/probe_registry.yaml` | Canonical payload contracts per probe — what the CLI produces and the Arena validates |
| `contracts/rules.yaml` | Machine-readable rule definitions — what the Arena evaluates |
| `contracts/rules.md` | Rule evaluation semantics |
| `contracts/normalizer_spec.md` | How raw SQL output is transformed into canonical payloads |
| `contracts/normalizer_interface_contract.md` | Boundary between SQL runner and normalizer |

### Inception Docs

See `docs/README.md` for the full document inventory and recommended reading order.

## Key Concepts

**Personas:** DBA/SRE, App Developer, CTO/Eng Leadership — each with different objectives and risk sensitivity.

**Workload Types:** OLTP, OLAP, Hybrid, Queue/Event-driven, Vector/Embedding, Multi-tenant SaaS.

**Health Domains:** Availability, Performance, Concurrency, Storage, Efficiency, Cost, Operational Hygiene.

**Assessment Profiles:** `default`, `performance`, `reliability`, `cost_capacity`, `supabase_default`.

**Probes:** 25 SQL-based evidence collectors (16 generic PostgreSQL + 9 Supabase-specific).

**Findings:** 25 interpretive results with severity, confidence, and score effects.

## Supabase-Specific Features

- **RLS policy column indexing** — detects missing indexes on Row Level Security filter columns
- **Realtime replication slot health** — detects WAL bloat from unconsumed logical replication slots
- **Auth schema health** — monitors vacuum and bloat on auth tables
- **Storage objects health** — detects soft-delete pressure on storage.objects
- **System schema bloat** — monitors platform-managed schemas
- **PgBouncer/Supavisor pool health** — detects pool mode misconfiguration
- **Tier-aware scoring** — adjusts thresholds based on Supabase instance tier
- **Feature interaction awareness** — PostgREST + RLS, Realtime + writes, Auth + traffic

## How to Use This Repo

### For manual assessments
Run SQL probes directly via `psql`. Use `docs/01_methodology.md` for the checklist and `docs/sample_report_template.md` for report structure.

### For CLI development
Work in `cli/`. Read `cli/CLAUDE.md` first. Use contracts as the implementation spec. Follow `docs/IMPLEMENTATION_PLAN.md`.

### For Arena development
Work in `arena/`. Read `arena/CLAUDE.md` first. Start with the schema migration from `docs/03_data_model.md`.

### For agentic development
Read `CLAUDE.md` at the top level. It will route you to the right island.
