# Plan: Rewrite Stub Context Files with Full Conversation Detail

## Goal

Rewrite the 13 stub/skeleton markdown files (01–11 series) that ChatGPT generated as compressed summaries, restoring the full detail developed across the conversation. The well-specified files (`rules.yaml`, `probe_registry.yaml`, `normalizer_spec.md`, `normalizer_interface_contract.md`, `rules.md`, `CONTRIBUTING.md`, `IMPLEMENTATION_PLAN.md`, `sample_report_template.md`) are already adequate and should not be modified.

## Source Material

- `chatgpt-conversation.md` — the full 6,571-line conversation transcript, already in the repo
- The gap analysis performed in the current Claude Code session identifying specific content losses per file

## Files to Rewrite (in order)

### 1. `01_methodology.md`

**Current state:** 13 lines, 4 bullet points.

**Target content (from conversation lines 7–262):**

- The 10-step methodology framework:
  1. **Evaluation intent** — 5 intent types: reliability assurance (DBA/SRE), performance optimization (developer), cost/capacity optimization (CTO/finance), pre-scale validation, post-incident forensics. Each with description of what "healthy" means.
  2. **Persona → Objective mapping** — Full matrix table: Persona | Primary Objective | Secondary Objective | Risk Sensitivity. Three personas: DBA/SRE (availability/stability, operability, very low incident tolerance), App Developer (query latency/correctness, predictability, moderate), CTO/Eng Leadership (cost efficiency/scalability, forecastability, high for waste).
  3. **Workload classification** — 5 types: OLTP (latency-sensitive, high concurrency), OLAP (scan-heavy, throughput), Hybrid/HTAP, Queue/Event-driven (write-heavy, append-only), Multi-tenant SaaS (noisy neighbor risk). Include the insight: "a 200ms query is catastrophic in OLTP, irrelevant in OLAP."
  4. **Health domains** — 7 orthogonal domains (A–G): Availability & Resilience, Performance & Latency, Resource Efficiency, Storage & Data Shape, Concurrency & Contention, Operational Hygiene, Cost & Capacity. Each with 3-5 specific sub-items.
  5. **KPI layer** — Concrete metrics per domain from pg_stat_statements, pg_locks, bloat ratio, cache hit ratio, replication lag, WAL generation rate, etc.
  6. **Diagnostic layer** — Interpretation heuristics: "High CPU + low I/O → inefficient queries or missing indexes", "High I/O + low cache hit → working set > memory", "High latency + low CPU → lock contention or I/O stalls", "Bloat + high write rate → autovacuum misconfiguration".
  7. **Scoring model** — 0–100 per domain, weighted by persona intent, with example weights.
  8. **Output structure** — Executive summary (persona-specific), key risks (ranked), root causes (not symptoms), recommended actions (prioritized by impact vs effort), capacity forecast.
  9. **End-to-end example flow** — 7 steps from identify persona to produce remediation plan.
  10. **Design principles** — What was strong in the initial thinking, what to tighten (formal domains, separate metrics from interpretation, add scoring + prioritization).

- The core formula: `Health = f(persona, objective, workload, evidence, interpretation)`
- The data flow: `Context → Evidence → Interpretation → Scores → Report`
- The principle: "Context defines the meaning of evidence"
- The correction from later conversation: probes are only one input channel; interpretation is multi-layered

---

### 2. `02_assessment_model.md`

**Current state:** 23 lines, bullet list.

**Target content (from conversation lines 1821–2103, 2196–2250):**

- Assessment as a first-class entity — tree structure:
  ```
  Assessment
    ├── Metadata (customer, project, timestamp)
    ├── Context (persona, workload, objectives)
    ├── Evidence (SQL probes, platform data)
    ├── Findings (derived)
    ├── Scores (by domain)
    ├── Recommendations
    └── Status (in progress, review, delivered)
  ```
- Four required capabilities: Ingestion, State Management, Computation, Output
- The 8-step lifecycle: create → populate platform data → collect customer context → run probes → generate findings → score → review → deliver report
- The 5 design principles: (1) distinguish facts/customer/derived/judgments, (2) append-only evidence, (3) separate rule outputs from raw evidence, (4) allow partial completion, (5) don't over-normalize v1
- The 6 entity types: assessments, assessment_inputs, assessment_evidence, assessment_findings, assessment_scores, assessment_reports, (optionally assessment_events)
- The mental model: assessments = the case, inputs = assertions/context, evidence = observations, findings = interpretations, scores = rollups, reports = deliverables

---

### 3. `03_context_ingestion.md`

**Current state:** 26 lines.

**Target content (from conversation lines 1494–1795):**

- The three-layer framework separation: Assessment model (generic) → Evidence model (what inputs needed) → Implementation model (how Supabase obtains them)
- **Evidence provenance matrix** — Full table: Variable | Needed in framework? | Source | Requires customer interview? With ~12 rows (primary persona, business objective, workload type, PG version, managed vs self-hosted, extensions, HA topology, replication status, query latency profile, capacity growth, SLO/RPO/RTO, cost sensitivity)
- **Two-track intake model:**
  - Customer-context intake: application purpose, critical workloads, pain points, performance expectations, growth, business events, tolerance levels
  - Platform-context intake: PG version, instance type/sizing, storage, extensions, replication topology, backups/PITR, connections, query stats, vacuum health, lock patterns
- **Canonical input keys for v1** — Platform-derived (~9): postgres_version, managed_service, extensions, compute_tier, storage_bytes, replica_count, pitr_enabled, max_connections, pgbouncer_enabled. Customer-derived (~11): primary_persona, primary_objective, secondary_objectives, workload_type, application_description, critical_services, latency_slo, availability_target, growth_expectation, cost_sensitivity, recent_incidents. Operator-derived (~3): assessment_scope, notes, special_constraints.
- **YAML schema examples** for both platform-derived and customer-derived input definitions (with id, label, domain, required, source_of_truth, customer_input_required, collection_method, affects, allowed_values fields)
- **Two-pass scoring model:** Pass 1 = technical baseline from observable evidence; Pass 2 = business-context-adjusted after understanding workload/objectives
- The metadata per input: source_of_truth, collection_method, customer_visible/internal-only
- The checklist split: Section A (auto-populated platform facts), Section B (customer-derived business context), Section C (derived assessment outputs)
- The key insight: "You only ask the customer what only the customer can know"

---

### 4. `03_data_model.md`

**Current state:** 16 lines.

**Target content (from conversation lines 2252–2465):**

- Full SQL schema with all 7 tables:
  - Enum types: `assessment_status` (draft, intake_in_progress, evidence_in_progress, analysis_in_progress, review, completed, archived), `input_source` (platform, customer, operator, derived), `evidence_source` (cli_probe, platform_api, manual_entry, imported), `finding_severity` (info, low, medium, high, critical), `finding_status` (open, accepted, dismissed, resolved)
  - `assessments` table — all columns: id, project_ref, organization_ref, created_at, updated_at, created_by, assigned_to, status, title, objective, primary_persona, workload_type, platform_context (jsonb), customer_context (jsonb), started_at, completed_at, tags. Plus indexes.
  - `assessment_inputs` table — id, assessment_id, key, value (jsonb), source, confidence, collected_at, collected_by, notes. Unique constraint on (assessment_id, key, source).
  - `assessment_evidence` table — id, assessment_id, source, probe_name, probe_version, collected_at, collected_by, target_scope, status, payload (jsonb), metadata (jsonb), error_text.
  - `assessment_findings` table — id, assessment_id, finding_key, domain, severity, status, title, summary, impact_text, recommendation_text, evidence_refs (jsonb), rule_metadata (jsonb), confidence, timestamps, created_by, reviewed_by. Unique on (assessment_id, finding_key).
  - `assessment_scores` table — assessment_id (PK), scoring_profile, computed_at, per-domain scores (numeric(5,2)), overall_score, score_payload (jsonb).
  - `assessment_reports` table — id, assessment_id, report_type, report_version, created_at, created_by, content_markdown, content_json (jsonb), metadata (jsonb).
  - `assessment_events` table — id, assessment_id, event_type, event_time, actor, payload (jsonb).
- Design rationale for each table
- `platform_context` vs `assessment_inputs` — when to use each, with JSON examples
- The `assessment_profile` column addition

---

### 5. `04_assessment_orchestration.md`

**Current state:** 31 lines.

**Target content (from conversation lines 1800–2184):**

- **Arena evaluation** — 6 candidates evaluated with strengths, limitations, conclusions:
  - A. Document-centric (Notion, Google Docs) — good for narrative, no workflow/typing/integration. Conclusion: presentation layer only.
  - B. CLI-only — excellent collection, stateless/no persistence/collaboration. Conclusion: instrument, not arena.
  - C. Slack/ChatOps — good triggers/notifications, terrible system of record. Conclusion: control plane, not storage.
  - D. Spreadsheets — structured/familiar, weak integration/logic. Conclusion: transitional.
  - E. Database-backed (Supabase itself) — native fit, strong structure, JSONB for probes, supports workflows. Conclusion: most appropriate system of record.
  - F. Custom application — tailored UX, can enforce methodology, engineering cost. Conclusion: ideal long-term, backed by database.
- **Three-layer architecture:**
  - Layer 1: Data collection (Go CLI, SQL probes, platform metadata, JSON output)
  - Layer 2: System of record (Supabase Postgres storing assessments, probes, findings, scores, context)
  - Layer 3: Interface/workflow — 3 options: minimal web UI, Slack thin interface, CLI-driven workflow
- **Workflow model** — 8-step process: create assessment → gather inputs → run probes → iterate → compare → refine → store → revisit
- **Four required capabilities:** Ingestion (CLI + APIs → DB, manual → DB), State Management (assessments table + status), Computation (rule engine via Go service or SQL/edge functions), Output (rendered reports)
- **Key principle:** "The arena is a persistent, queryable representation of assessments with a defined lifecycle. Everything else is just an interface into it."
- **Strategic insight:** Once assessments are stored structurally, unlocks cross-customer benchmarking, pattern detection, product feedback loops, automated recommendations

---

### 6. `04_probe_system.md`

**Current state:** 22 lines.

**Target content (from conversation lines 527–932, 3151–5067):**

- Probe classification: baseline probes (run almost always), contextual probes (justified by profile/symptoms), optional probes (require specific privileges/extensions)
- Per-probe model: probe name, purpose, prerequisites, execution scope, payload shape, candidate findings, affected score domains, interpretation notes
- The 15 v1 probes with condensed descriptions (full detail is in probe_registry.yaml, but this file should provide the human-readable purpose, interpretation notes, and inter-probe relationships that the YAML doesn't capture)
- Probe-to-finding mapping matrix (which probes support which findings, including primary vs corroboration roles)
- Probe-to-score-domain mapping (primary vs secondary probes per domain)
- Probe prerequisites matrix (table: Probe | Requires extension | Requires special privilege | Notes)
- Probe profiles: default (all baseline + pg_stat_statements if available), performance, reliability, cost_capacity — with specific probes listed per profile
- Implementation prioritization: First wave (8 probes), Second wave (4 probes), Third wave (3 probes)
- Optional v1.1 probes list: vacuum_progress, analyze_progress, cache_hit_ratio, sequential_scan_heavy_tables, role_inventory, bloat_estimate, table_xid_age, prepared_transactions, replica_conflicts
- The standardized evidence payload wrapper contract
- The probe registry spec (YAML format per entry)

---

### 7. `05_rule_engine.md`

**Current state:** 22 lines.

**Target content (from conversation lines 958–1299, 4375–4768):**

- The diagnostic layer concept: "Metrics alone are not enough—you need interpretation rules"
- 15 rule definitions with specific logic:
  - `long_running_transactions_detected`: high if > 1h, medium if > 15min, low if > 5min in OLTP, increase if idle-in-transaction
  - `idle_in_transaction_sessions_detected`: high if count ≥ 3 and oldest > 15min, medium if ≥ 1 and > 5min
  - `active_lock_blocking_detected`: high if blocked count > 3, medium if any pair, critical if DDL blocker
  - `deadlocks_observed`: medium if > 0, high if exceeds modest threshold
  - `high_connection_utilization`: medium if > 80%, high if > 90%
  - `significant_temp_spill_activity`: medium if substantial spill, high if large + high latency, downgrade in OLAP
  - `high_impact_query_total_time`: medium if few queries dominate, high if clear outlier + perf/cost objective
  - `high_latency_queries_detected`: workload-profile-dependent, increase in OLTP, decrease in OLAP
  - `dead_tuple_accumulation_detected`: medium if large tables show substantial %, high if paired with old xacts/stale vacuum
  - `stale_vacuum_or_analyze_detected`: medium if large relations have null/old timestamps, high if paired with dead tuples
  - `potentially_unused_large_indexes`: low/medium with zero scans, never high in v1, rises with size
  - `replication_lag_elevated`: medium/high by magnitude, increase if replicas serve reads
  - `checkpoint_pressure_detected`: medium if requested frequent, high if buffers_backend indicates pressure
  - `diagnostic_visibility_limited`: low/medium if key extensions absent, meta-finding
  - `storage_concentration_risk`: low/medium if few relations dominate
- Rule design principles: (1) workload-relative signals, (2) many signals require history not single snapshot, (3) several checks inherently low-confidence from catalog views alone
- Rule attributes: workload context, confidence, prerequisites, whether history is required

---

### 8. `06_scoring_model.md`

**Current state:** 20 lines.

**Target content (from conversation lines 190–210, 1014–1054, 2936–2966):**

- Scale: 0 to 5 (with definitions: 5=healthy, 4=minor issues, 3=moderate concern, 2=high concern, 1=critical risk, 0=unknown/insufficient evidence). Note: later revised to 0-100 in implementation.
- 7 score domains: availability, performance, concurrency, storage, efficiency, cost, operational_hygiene
- Persona-specific weight examples:
  - DBA/SRE: availability 25%, concurrency 20%, storage 20%, performance 15%, efficiency 10%, security/hygiene 10%
  - CTO: cost and capacity heavier, performance/maintenance lower unless tied to customer impact
- The principle: "Do not overfit numeric precision. The score is a communication device, not science."
- Concrete JSON score payload example with weights, per-domain scores, overall score, and rationale array
- The implementation model: initialize at 100, apply additive deltas from matched rules, clamp 0–100, compute weighted overall outside rule engine
- Two-pass scoring: technical baseline first, then business-context-adjusted after understanding workload/objectives
- Score transparency: "Do not hide scoring logic behind a single opaque number"

---

### 9. `07_cli_contract.md`

**Current state:** 21 lines.

**Target content (from conversation lines 2616–2898):**

- 8 CLI commands with full conceptual examples:
  1. `supabase db health init` — flags: --project-ref, --created-by, --title, --objective, --primary-persona, --workload-type. Request/response JSON.
  2. `supabase db health input set` — single key/value. Flags: --assessment-id, --source, --key, --value.
  3. `supabase db health input import` — batch from file. Batch JSON payload with array of inputs.
  4. `supabase db health probe run` — flags: --assessment-id, --profile, --target, --upload. Evidence upload JSON payload with partial success handling.
  5. `supabase db health analyze` — triggers server-side analysis. Response with findings_created/updated, scores_updated.
  6. `supabase db health report generate` — flags: --assessment-id, --format.
  7. `supabase db health show` — returns assessment summary with scores and finding counts.
  8. `supabase db health findings list`
- API endpoint set: POST /assessments, PATCH /assessments/{id}, POST .../inputs:batchUpsert, POST .../evidence:batchCreate, POST .../analyze, POST .../reports, GET /assessments/{id}, GET .../findings, GET .../scores
- State transitions: draft → intake_in_progress → evidence_in_progress → analysis_in_progress → review → completed → archived (with descriptions of what triggers each)
- Complete JSON response examples for each operation
- The design principle: "CLI should be a client of this contract, not a direct schema manipulator"
- What CLI should NOT do in v1: be system of record, embed large rule sets, generate non-reproducible findings, tightly couple probe format to report format

---

### 10. `08_probe_catalog.md`

**Current state:** 19 lines (list of names only).

**Target content (from conversation lines 3151–5067):**

- Per-probe entries (15 probes) with: purpose, prerequisites, execution scope, collected fields, candidate findings, affected score domains, interpretation notes
- Probe-to-finding mapping matrix (the complete matrix showing which probes support which findings, including "as context only", "as corroboration", and direct support roles)
- Probe-to-score-domain mapping (per domain: primary probes and secondary probes)
- Probe prerequisites matrix (table format)
- Probe profiles (default, performance, reliability, cost_capacity with specific probes)
- Implementation waves (first/second/third)
- Summary of strongest probes, most actionable findings, best score coverage

---

### 11. `09_findings_catalog.md`

**Current state:** 17 lines (list of names only).

**Target content (from conversation lines 4086–4768):**

- 15 v1 findings with: inputs (which probes), logic (threshold conditions, workload sensitivity), affected domains, confidence level
- The mapping from findings to probes (reverse of probe-to-finding)
- Severity gradation logic per finding

---

### 12. `10_roadmap.md`

**Current state:** 22 lines.

**Target content (from conversation lines 1304–1372):**

- 4 phases with specific deliverables and goals:
  - Phase 1 (Manual but standardized): checklist, SQL pack, scoring rubric, report template. Goal: every SA/DBA runs the same review.
  - Phase 2 (CLI audit tool): probe execution, JSON output, markdown report generation, 15-20 rules, OLTP/OLAP profiles. Goal: reduce toil, improve consistency.
  - Phase 3 (Time-series aware): snapshot persistence, diffing between runs, trend-based findings, growth/capacity forecasts. Goal: move from point-in-time to operational posture.
  - Phase 4 (Productization): hosted dashboard/internal portal, customer-ready executive summaries, remediation playbooks, fleet-wide benchmarking. Goal: repeatable customer success mechanism.
- The Supabase-specific refinement of phases (from later conversation)
- v1 implementation sequence: schema → init/import/probe → evidence storage → minimal analysis (5-10 rules) → markdown report → scoring refinements

---

### 13. `11_cross_assessment_model.md`

**Current state:** 21 lines.

**Target content (from conversation lines 2170–2184, 6200–6330):**

- Strategic value: once assessments are stored structurally, unlocks capabilities beyond individual reports
- Specific capabilities: cross-customer benchmarking, pattern detection (e.g., "80% of customers have autovacuum issues"), product feedback loops (what Supabase should fix at platform level), automated recommendations over time
- Comparison axes: workload type, database size, score distributions, findings frequency
- Future capabilities: benchmarking, anomaly detection, pattern recognition
- Constraints: anonymization, normalization, stable scoring required
- The principle: "More data → better insights" but only if normalization + scoring are stable
- Why it should be acknowledged now even if not implemented: prevents architectural dead ends later (single-assessment-scoped design would box the system in)

---

## Approach

- Rewrite each file preserving the numbered prefix naming convention
- Use the conversation as the primary source; cross-reference existing well-specified files (rules.yaml, probe_registry.yaml) to avoid duplication where appropriate
- Include concrete examples (SQL, JSON, YAML, tables) from the conversation
- Reference related files (e.g., "See `rules.yaml` for the machine-readable rule definitions") rather than duplicating content that's already well-specified elsewhere
- Keep the tone technical and direct — these are design documents, not marketing
- Do not add content that wasn't in the conversation

## Execution Order

Rewrite in dependency order:
1. `01_methodology.md` — foundational, referenced by everything
2. `02_assessment_model.md` — defines the core object model
3. `03_context_ingestion.md` — defines non-probe inputs
4. `03_data_model.md` — defines the persistence schema
5. `04_assessment_orchestration.md` — defines the workflow/arena
6. `06_scoring_model.md` — scoring model (referenced by probe/rule docs)
7. `04_probe_system.md` — probe system overview
8. `05_rule_engine.md` — rule engine overview
9. `08_probe_catalog.md` — detailed probe catalog
10. `09_findings_catalog.md` — detailed findings catalog
11. `07_cli_contract.md` — CLI contract
12. `10_roadmap.md` — phased roadmap
13. `11_cross_assessment_model.md` — cross-assessment model

## Success Criteria

- Every file contains the substantive detail from the conversation, not just summaries
- Tables, SQL, JSON, and YAML examples from the conversation are preserved
- Files cross-reference each other and the well-specified files appropriately
- No new content is invented — only conversation content is restored
- The README.md should be updated to reflect the richer document set
