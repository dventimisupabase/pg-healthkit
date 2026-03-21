# Assessment Orchestration

## Purpose

Defines the "arena" — the system and workflow for managing health assessments. This is not just a tooling choice; it is a systems design problem. The assessment system requires a persistent, queryable representation of assessments with a defined lifecycle. Everything else is just an interface into it.

## Arena Evaluation

Six candidate platforms were evaluated:

### A. Document-centric tools (Notion, Google Docs)

| Aspect          | Assessment                                                                                                    |
|-----------------|---------------------------------------------------------------------------------------------------------------|
| **Strengths**   | Good for narrative output, easy collaboration, low friction                                                   |
| **Limitations** | No strong typing, no real workflow/state machine, no programmatic integration with probes, no reproducibility |
| **Conclusion**  | Useful as a **presentation layer**, not as the system of record                                               |

### B. CLI-only approach (Go CLI)

| Aspect          | Assessment                                                                                           |
|-----------------|------------------------------------------------------------------------------------------------------|
| **Strengths**   | Excellent for data collection, deterministic, automatable, easy to integrate with Supabase internals |
| **Limitations** | Stateless, no persistence, no collaboration, no workflow visibility                                  |
| **Conclusion**  | This is an **instrument**, not the arena                                                             |

### C. Slack / ChatOps

| Aspect          | Assessment                                                                               |
|-----------------|------------------------------------------------------------------------------------------|
| **Strengths**   | Good for triggering workflows, notifications, collaboration; fits existing team behavior |
| **Limitations** | Terrible as a system of record, hard to structure data, hard to audit or reproduce       |
| **Conclusion**  | Useful as a **control plane / interface**, not storage                                   |

### D. Spreadsheet / lightweight tabular tools

| Aspect          | Assessment                                                                       |
|-----------------|----------------------------------------------------------------------------------|
| **Strengths**   | Structured, familiar, decent for tracking                                        |
| **Limitations** | Weak integration with probes, no strong workflow or logic layer, breaks at scale |
| **Conclusion**  | **Transitional** at best                                                         |

### E. Database-backed system (Supabase itself)

| Aspect          | Assessment                                                                                                                                                                                                                           |
|-----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Strengths**   | Native fit (evaluating Postgres with Postgres), strong structure for assessments, easy to store probe outputs (JSONB), supports workflows/state/versioning, integrates with Supabase auth/edge functions/storage, enables automation |
| **Limitations** | Requires some upfront design, needs a UI or interface layer                                                                                                                                                                          |
| **Conclusion**  | **Most appropriate system of record**                                                                                                                                                                                                |

### F. Custom application (internal tool)

| Aspect          | Assessment                                                                                                               |
|-----------------|--------------------------------------------------------------------------------------------------------------------------|
| **Strengths**   | Tailored UX for assessments, can enforce methodology, can integrate CLI + platform + reporting, can scale into a product |
| **Limitations** | Engineering cost, requires prioritization                                                                                |
| **Conclusion**  | **Ideal long-term arena**, backed by a database. Not mutually exclusive with E — sits on top of it                       |

## Three-Layer Architecture

### Layer 1 — Data Collection (partially solved)

- Go CLI (existing Supabase CLI + extensions)
- Runs SQL probes
- Pulls platform metadata
- Outputs structured JSON

### Layer 2 — System of Record (the "laboratory")

A Supabase Postgres database that stores:
- Assessments
- Probe results (evidence)
- Derived findings
- Scoring outputs
- Customer context
- Reports

See `04_data_model.md` for the schema. See `08_cli_contract.md` for the CLI integration contract.

### Layer 3 — Interface / Workflow

Multiple viable entry points:

**Option 1 (fastest): Supabase + minimal UI**
- Simple internal web app (Next.js or similar)
- Shows assessments, findings, scores
- Allows manual input (customer context)
- Renders reports

**Option 2: Slack as a thin interface**
- `/db-health start <project>` triggers assessment creation
- CLI runs asynchronously
- Results stored in DB
- Slack posts summary + link to UI

**Option 3: CLI-driven workflow (initial phase)**
```
supabase db health init
supabase db health run
supabase db health report
```
But crucially: **CLI writes to the database**, not to local files only.

## Per-Assessment Workflow Phases

Each individual assessment follows a five-phase workflow. This is distinct from the product maturity roadmap (see `13_roadmap.md`), which describes how the system itself evolves over time.

### Phase 0: Pre-population

Supabase auto-fills everything available from internal metadata, observability, and database probes **before any customer contact**. This enables a draft health profile that can:

- Identify likely risk areas in advance
- Focus the customer conversation on validation rather than data gathering
- Produce a technical baseline score (Pass 1) without customer input

This is a major advantage for a managed service provider.

### Phase 1: Customer Discovery

Ask only the missing high-value questions:

- What is the system for?
- What workloads matter most?
- What symptoms are observed?
- What constraints matter most (latency, uptime, cost, scale, compliance)?
- What upcoming changes are expected?

### Phase 2: Probe Execution

Run SQL and platform probes. Evidence is collected and stored.

### Phase 3: Interpretation

Evaluate findings in the context of both the auto-filled facts and customer intent. Apply business-context-adjusted scoring (Pass 2).

### Phase 4: Output

Produce a report with findings, confidence, and recommendations.

### Detailed Workflow Steps

Once backed by a database, the detailed workflow within these phases is:

1. **Create assessment** — auto-populate platform data (Phase 0)
2. **Run probes** — CLI → DB (Phase 0 / Phase 2)
3. **Add customer context** — manual input (Phase 1)
4. **Review evidence** — human (Phase 2)
5. **Generate findings** — rules engine (Phase 3)
6. **Adjust severity** — human override if needed (Phase 3)
7. **Generate report** — templated output (Phase 4)
8. **Mark complete** — status transition (Phase 4)

This is the "laboratory process." It is iterative, not one-shot. An assessment may cycle through probe → review → refine multiple times.

> **Note:** These per-assessment workflow phases (0–4) are not the same as the product maturity phases (Phase 1–4) in `13_roadmap.md`. The roadmap phases describe how the pg-healthkit system itself evolves (Manual → CLI → Time-series → Productization). The per-assessment phases describe the lifecycle of a single health evaluation.

## Four Required Capabilities (satisfied)

| Capability           | How Satisfied                                              |
|----------------------|------------------------------------------------------------|
| **Ingestion**        | CLI + platform APIs → DB; manual inputs → DB               |
| **State Management** | `assessments` table + `status` field + `assessment_events` |
| **Computation**      | Rule engine (Go service or SQL/edge functions)             |
| **Output**           | Rendered reports (Markdown/HTML/PDF)                       |

## Key Principle

> The "arena" is not Notion, Slack, or CLI. The arena is **a persistent, queryable representation of assessments with a defined lifecycle**. Everything else is just an interface into it.

## Strategic Insight

Once assessments are stored structurally, you unlock something more valuable than individual reports:

- **Cross-customer benchmarking** — compare patterns across workloads and database sizes
- **Pattern detection** — e.g., "80% of customers have autovacuum issues"
- **Product feedback loops** — what Supabase should fix at platform level
- **Automated recommendations over time** — learning from historical assessments

That is where this becomes strategically important, not just operationally useful.

## Existing Supabase CLI Capabilities

The Supabase CLI (`supabase`) already has a `db inspect` subcommand with early diagnostic queries. Before implementing new probes, the existing inspection component should be inventoried to:

- **Avoid duplication** — reuse existing diagnostic outputs where they match probe requirements
- **Identify gaps** — determine which v1 probes need new SQL beyond what `db inspect` already provides
- **Enable parallel tracks** — the SQL probes can be run directly via `psql` or shared with customers while the Go CLI integration follows the standard SDLC (patches, PRs, review, merge)

The CLI contract in `08_cli_contract.md` should accommodate importing existing `db inspect` outputs as evidence records (via `evidence_source = 'imported'`), allowing the assessment system to ingest data from the existing tooling as well as from new probes.

## Practical v1 Recommendation

Do not overbuild. Start with:

1. Use Supabase (Postgres) as the backend
2. Extend the existing Go CLI to run probes and insert results into DB
3. Use Notion or Markdown only for final report output initially
4. Add a very thin internal UI later

That gives you:
- Structure without heavy engineering
- Reproducibility
- Shared visibility
- A path to productization
