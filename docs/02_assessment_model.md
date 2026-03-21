# Assessment Model

## Core Abstraction

Each customer evaluation is a first-class entity — an **assessment**. It is not an ad hoc collection of queries and notes. It is a structured, stateful object with a defined lifecycle.

```
Assessment
  ├── Metadata (customer, project, timestamp, operator)
  ├── Context (persona, workload, objectives)
  ├── Inputs (customer-supplied + platform-derived)
  ├── Evidence (probe results, platform telemetry)
  ├── Findings (derived from rules)
  ├── Scores (by domain, weighted)
  ├── Recommendations (prioritized)
  └── Status (lifecycle state)
```

## Four Required Capabilities

The system managing assessments must satisfy four functions simultaneously:

| Capability           | Description                                | What Satisfies It                                          |
|----------------------|--------------------------------------------|------------------------------------------------------------|
| **Ingestion**        | Collect structured and unstructured inputs | CLI + platform APIs → DB; manual inputs → DB               |
| **State Management** | Track an assessment as an evolving object  | Assessments table with status field and lifecycle          |
| **Computation**      | Run probes, scoring, and heuristics        | Rule engine (Go service, SQL functions, or edge functions) |
| **Output**           | Produce consistent, high-quality reports   | Rendered reports (Markdown / HTML / PDF)                   |

Most individual tools (Notion, Slack, CLI) cover only 1–2 of these. The assessment model requires all four.

## Assessment Lifecycle

```
draft
  → intake_in_progress      (once contextual inputs begin)
    → evidence_in_progress   (once probes start)
      → analysis_in_progress (when findings/scoring run)
        → review             (when human review starts)
          → completed        (when report is final)
            → archived       (if superseded or closed)
```

### Step-by-step:

1. **Create assessment** — auto-populate platform data where available
2. **Populate platform context** — PG version, extensions, topology, sizing (no customer interaction required)
3. **Collect customer context** — persona, objectives, workload type, application description, constraints
4. **Run probes** — execute SQL probes, collect evidence, normalize payloads
5. **Generate findings** — evaluate rules against normalized evidence
6. **Score** — compute per-domain and overall scores, weighted by profile
7. **Review** — human operator reviews findings, adjusts severity where appropriate
8. **Deliver report** — produce persona-aware report, store as deliverable

## Design Principles

1. **Distinguish data types.** Facts gathered from the platform, facts gathered from the customer, derived findings, and final human judgments are not the same thing and should not live in the same column.

2. **Prefer append-only evidence.** Probe results are observations. You may want to re-run probes later and compare. Do not overwrite evidence destructively.

3. **Separate rule outputs from raw evidence.** Raw evidence should remain inspectable independently of findings. Findings reference evidence but do not replace it.

4. **Allow partial completion.** An assessment should be valid even if some evidence is missing. Probes may be skipped; customer context may be incomplete. The system should produce the best assessment possible with available data.

5. **Don't over-normalize v1.** Use relational structure for core entities and JSONB for variable payloads. Avoid premature abstraction.

## Entity Model

For v1, the following entities are sufficient:

| Entity                | Role                   | Mental Model                                          |
|-----------------------|------------------------|-------------------------------------------------------|
| `assessments`         | The case               | The top-level container for a health evaluation       |
| `assessment_inputs`   | Assertions and context | Structured key/value inputs with provenance           |
| `assessment_evidence` | Observations           | Raw probe outputs and imported telemetry              |
| `assessment_findings` | Interpretations        | Rule-derived insights that humans act on              |
| `assessment_scores`   | Rollups                | Computed per-domain and overall scores                |
| `assessment_reports`  | Deliverables           | Generated artifacts (Markdown, JSON, HTML)            |
| `assessment_events`   | Audit trail            | Cheap workflow history without full workflow modeling |

See `04_data_model.md` for the complete SQL schema.

## Assessment Profiles

Assessments should be tagged with a profile that drives probe selection, threshold interpretation, and scoring weights:

| Profile         | Primary Use Case                       |
|-----------------|----------------------------------------|
| `default`       | General health review                  |
| `performance`   | Developer-driven latency investigation |
| `reliability`   | DBA/SRE-driven availability assurance  |
| `cost_capacity` | CTO-driven cost and sizing review      |

The profile is not exclusive — it determines emphasis, not hard boundaries.

## Partial Execution Before Customer Contact

A major advantage for a managed service provider: some of the methodology supports partial execution before talking to the customer.

In practice:
1. **Precompute a draft health profile** from observable platform and SQL evidence
2. **Identify likely risk areas** based on technical baseline scoring
3. **Use the customer conversation** to validate or reweight findings

Example: high temp spill and long-running reports may look problematic generically, but if the customer says "this is a nightly analytics job and latency is acceptable," severity changes. The evidence stays the same; the interpretation changes.

This suggests a **two-pass scoring model:**
- **Pass 1:** Technical baseline score — based only on observable platform and SQL evidence
- **Pass 2:** Business-context-adjusted score — reweighted after understanding workload and objectives

## Finding Structure

Each finding should have:

```json
{
  "finding_key": "long_running_transactions_detected",
  "domain": "concurrency",
  "severity": "high",
  "title": "Long-running transactions detected",
  "summary": "Transactions older than 1 hour were present during evidence collection.",
  "cause_text": "Application transaction boundaries are too broad, or sessions are being abandoned without rollback.",
  "impact_text": "May block vacuum and contribute to table bloat and lock contention.",
  "recommendation_text": "Investigate client transaction boundaries; terminate abandoned sessions where appropriate.",
  "evidence_refs": [
    { "probe_name": "long_running_transactions", "evidence_id": "uuid" }
  ],
  "confidence": "high"
}
```

See `12_findings_catalog.md` for the full v1 findings set.

## Report Structure

Every report should have the same shape:

1. **Executive summary** — assessment scope, workload classification, overall score, top 3 risks, top 3 recommended actions
2. **Domain scores** — per-domain breakdown
3. **Findings** — grouped by domain, each with title, severity, evidence, cause, remediation
4. **Appendix** — configuration snapshot, top queries, largest tables, maintenance stats, replication stats

See `sample_report_template.md` for the canonical template.
