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

See `03_data_model.md` for the schema.

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

## Workflow Model

Once backed by a database, the workflow is:

1. **Create assessment** — auto-populate platform data
2. **Run probes** — CLI → DB
3. **Review evidence** — human
4. **Add customer context** — manual input
5. **Generate findings** — rules engine
6. **Adjust severity** — human override if needed
7. **Generate report** — templated output
8. **Mark complete** — status transition

This is the "laboratory process." It is iterative, not one-shot. An assessment may cycle through probe → review → refine multiple times.

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

See `11_cross_assessment_model.md` for the cross-assessment model.

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
