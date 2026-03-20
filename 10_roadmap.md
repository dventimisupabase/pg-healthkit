# Roadmap

## Phase 1: Manual but Standardized

**Deliverables:**
- Standardized human checklist (sections A–J)
- SQL probe pack (15 probes organized by domain)
- Scoring rubric (7 domains, persona-weighted)
- Report template (executive summary + domain scores + findings + appendix)

**Goal:** Every SA/DBA runs the same review. Consistency across engagements without requiring tooling.

**Success criteria:**
- A new team member can run the full assessment using only the checklist and SQL files
- Reports are structurally comparable across customers
- No CLI or automation required

## Phase 2: CLI Audit Tool

**Deliverables:**
- Probe execution engine (Go, integrated into Supabase CLI)
- Profile-based probe selection (default, performance, reliability, cost_capacity)
- JSON evidence output with canonical payload normalization
- Markdown report generation from findings
- 15–20 rules with threshold-based evaluation
- OLTP and OLAP workload profiles
- Evidence persistence to Postgres-backed system of record

**Goal:** Reduce manual toil and improve consistency. An operator runs one command and gets a structured health report.

**Success criteria:**
- End-to-end flow works: init → probe → analyze → report
- Probes run or skip deterministically based on prerequisites
- Canonical payloads validate against registry contracts
- Rules produce stable, explainable findings
- Domain scores are computed reproducibly

## Phase 3: Time-Series Aware

**Deliverables:**
- Snapshot persistence (store assessment results for diffing)
- Diffing between runs (compare two assessments for the same project)
- Trend-based findings (detect regression or improvement over time)
- Growth and capacity forecasts (storage, WAL, connections)

**Goal:** Move from point-in-time health to operational posture. Assessments become longitudinal, not just snapshots.

**Success criteria:**
- Can compare "last month" vs "this month" for a given project
- Trend-based findings surface (e.g., "dead tuple ratio increased 3x since last assessment")
- Growth projections are generated for storage and WAL

## Phase 4: Productization

**Deliverables:**
- Hosted dashboard or internal portal
- Customer-ready executive summaries
- Remediation playbooks (structured action plans per finding type)
- Fleet-wide benchmarking (compare across customers)
- Automated recommendations over time

**Goal:** Turn this into a repeatable customer success mechanism and potentially a platform feature.

**Success criteria:**
- Internal teams use the tool routinely
- Cross-customer benchmarking identifies platform-level improvements
- Customers receive consistent, high-quality health reports

## v1 Implementation Sequence

Within Phase 2, implement in this order:

1. **Schema and persistence** — create the assessment database schema
2. **init, input import, probe run** — CLI can create assessments and collect evidence
3. **Evidence storage and retrieval** — evidence persists and can be inspected
4. **Minimal server-side analysis** — 5–10 rules producing findings and scores
5. **Markdown report generation** — human-readable output
6. **Scoring refinements and workflow polish** — persona-weighted scoring, profile support

This sequence gets an end-to-end loop working quickly.

## Recommended First Vertical Slice

If only one thin slice is built first:

1. Run `long_running_transactions`
2. Normalize payload
3. Evaluate `long_running_transactions_detected`
4. Render one finding in markdown

Then add `connection_pressure` + `idle_in_transaction_sessions_detected`, then `lock_blocking_chains`. This yields a usable concurrency-focused path quickly.

## Supabase-Specific Considerations

- The Go CLI already exists with an early inspection component
- Extending it involves the standard SDLC (patches, PRs, review, merge)
- On a parallel track, the SQL probes can be run directly via `psql` or shared with customers
- The implementation language (Go) is determined by organizational fit, not intrinsic superiority
- The SQL probes are the portable core; the CLI is the Supabase-specific wrapper
