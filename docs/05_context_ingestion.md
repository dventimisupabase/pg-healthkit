# Context Ingestion

## Purpose

Defines how non-SQL context enters the system. Probes gather evidence from the database, but health is a function of more than just database internals:

```
Health = f(persona, objective, workload, evidence, interpretation)
```

Persona, objectives, and workload type cannot be derived from SQL. They must be collected externally. They are **first-class inputs**, not optional metadata.

## Three-Layer Framework

The methodology separates into three layers:

| Layer                    | Scope                                | Portability                            |
|--------------------------|--------------------------------------|----------------------------------------|
| **Assessment model**     | Generic — domains, scoring, findings | Portable to any PostgreSQL environment |
| **Evidence model**       | What inputs are needed               | Portable — defines requirements        |
| **Implementation model** | How inputs are obtained              | Environment-specific (e.g., Supabase)  |

The assessment model stays generic. The evidence model defines what inputs are needed. The implementation model defines how a specific platform (e.g., Supabase) obtains them.

## Evidence Provenance Matrix

Every variable in the framework should be annotated with its source:

| Variable                         | Needed? | Source                         | Requires Customer Interview? |
|----------------------------------|---------|--------------------------------|------------------------------|
| Primary persona                  | Yes     | Customer / CSM / SA            | Yes                          |
| Business objective               | Yes     | Customer                       | Yes                          |
| Workload type (OLTP/OLAP/hybrid) | Yes     | Customer + telemetry inference | Usually yes                  |
| PostgreSQL version               | Yes     | Platform metadata              | No                           |
| Managed vs self-hosted           | Yes     | Platform metadata              | No                           |
| Extensions installed             | Yes     | Platform metadata / SQL        | No                           |
| HA topology                      | Yes     | Platform metadata              | No                           |
| Replication status               | Yes     | Platform telemetry / SQL       | No                           |
| Query latency profile            | Yes     | SQL / observability            | No                           |
| Capacity growth expectations     | Yes     | Customer + billing + telemetry | Often yes                    |
| SLO / RPO / RTO expectations     | Yes     | Customer                       | Yes                          |
| Cost sensitivity                 | Yes     | Customer / account team        | Yes                          |

The key insight: **you only ask the customer what only the customer can know.**

## Two-Track Intake Model

### Track 1: Customer-Context Intake

Captures things that cannot be inferred from the platform:

- What the application does
- Which workloads are business-critical
- Where pain is being felt (performance, reliability, cost, scale)
- Performance expectations (latency SLOs)
- Growth expectations (upcoming launches, seasonal patterns)
- Business events or launches
- Tolerance for downtime, lag, maintenance, and cost

### Track 2: Platform-Context Intake

What the platform (e.g., Supabase) can populate automatically:

- Postgres version
- Instance type / sizing
- Storage usage
- Extensions
- Replication topology
- Backups / PITR posture
- Connection patterns
- Query stats
- Vacuum health
- Lock patterns
- Existing diagnostic/inspection results

This separation is operationally important: it minimizes customer questioning and improves consistency.

## Canonical Input Keys (v1)

### Platform-derived

| Key                 | Type    | Source                  |
|---------------------|---------|-------------------------|
| `postgres_version`  | string  | Platform metadata / SQL |
| `managed_service`   | boolean | Platform metadata       |
| `extensions`        | array   | Platform metadata / SQL |
| `compute_tier`      | string  | Platform metadata       |
| `storage_bytes`     | integer | Platform metadata       |
| `replica_count`     | integer | Platform metadata       |
| `pitr_enabled`      | boolean | Platform metadata       |
| `max_connections`   | integer | Platform metadata / SQL |
| `pgbouncer_enabled` | boolean | Platform metadata       |

### Customer-derived

| Key                       | Type                                                       | Source             |
|---------------------------|------------------------------------------------------------|--------------------|
| `primary_persona`         | string                                                     | Customer interview |
| `primary_objective`       | string                                                     | Customer interview |
| `secondary_objectives`    | array                                                      | Customer interview |
| `workload_type`           | enum (oltp, olap, hybrid, queue, vector, multitenant_saas) | Customer interview |
| `application_description` | string                                                     | Customer interview |
| `critical_services`       | array                                                      | Customer interview |
| `latency_slo`             | string                                                     | Customer interview |
| `availability_target`     | string                                                     | Customer interview |
| `growth_expectation`      | string                                                     | Customer interview |
| `cost_sensitivity`        | string                                                     | Customer interview |
| `recent_incidents`        | string                                                     | Customer interview |

### Operator-derived

| Key                   | Type   | Source            |
|-----------------------|--------|-------------------|
| `assessment_scope`    | string | Operator judgment |
| `notes`               | string | Operator          |
| `special_constraints` | string | Operator          |

## Input Schema Examples

Platform-derived input definition:

```yaml
id: postgres_version
label: PostgreSQL version
domain: platform_context
required: true
source_of_truth: platform_metadata
customer_input_required: false
collection_method: internal_api
affects:
  - compatibility
  - extension_support
  - maintenance_posture
```

Customer-derived input definition:

```yaml
id: workload_type
label: Primary workload type
domain: business_context
required: true
source_of_truth: customer_interview
customer_input_required: true
collection_method: questionnaire
allowed_values:
  - oltp
  - olap
  - hybrid
  - queue
  - vector
  - multitenant_saas
affects:
  - threshold_profile
  - scoring_weights
  - remediation_priority
```

## Input Metadata

Each input should carry:

| Field               | Purpose                                                                             |
|---------------------|-------------------------------------------------------------------------------------|
| `source_of_truth`   | Where the authoritative value comes from                                            |
| `collection_method` | How the value is obtained (internal_api, SQL probe, questionnaire, operator lookup) |
| `customer_visible`  | Whether the input is appropriate to share with the customer                         |

This tells you what can be automated now and what cannot.

## How Context Influences the System

Context is not passive metadata. It actively shapes:

### Rule evaluation
- Workload type conditions severity thresholds (e.g., 500ms query: OLTP → severe, OLAP → normal)
- Rules reference `assessment_context.workload_type` in their conditions

### Scoring
- Persona determines domain weight distribution
- Two-pass scoring: technical baseline first, then business-context-adjusted

### Report framing
- Executive summary is persona-specific
- Recommendations are prioritized by the stated business objective
- Severity language is calibrated to the audience (DBA vs CTO)

## Two-Pass Scoring Model

**Pass 1: Technical baseline score.**
Based only on observable platform and SQL evidence. No customer context required.

**Pass 2: Business-context-adjusted score.**
Reweighted after understanding workload and objectives. Evidence stays the same; interpretation changes.

This is a better fit for managed service providers than a single-pass model, because it supports partial execution before talking to the customer.

## Checklist Split

The human checklist should be organized into three sections:

| Section                                  | Content                                                            | Source                    |
|------------------------------------------|--------------------------------------------------------------------|---------------------------|
| **A. Auto-populated platform facts**     | Everything the platform can determine without customer interaction | Platform APIs, SQL probes |
| **B. Customer-derived business context** | Everything requiring customer explanation                          | Discovery conversation    |
| **C. Derived assessment outputs**        | Classification, scores, findings, recommendations                  | Rule engine, scoring      |

This avoids mixing raw facts with interpretation.

## Supabase-Specific Notes

For Supabase, the four evidence channels are:

1. Internal platform metadata (version, sizing, topology)
2. SQL probes against the customer database
3. Existing Supabase inspect/diagnostic outputs
4. A very short customer interview template

Many variables that would require customer input in a generic context are platform-derivable at Supabase. The methodology stays generic; the implementation becomes more efficient.

### Supabase Platform Inputs (auto-derivable)

These additional platform-derived inputs should be collected for Supabase assessments:

| Key                         | Type                           | Source            |
|-----------------------------|--------------------------------|-------------------|
| `supabase_tier`             | string (small/medium/large/xl) | Platform metadata |
| `supabase_region`           | string                         | Platform metadata |
| `auth_provider`             | string (supabase/external)     | Platform metadata |
| `realtime_enabled`          | boolean                        | Platform metadata |
| `storage_enabled`           | boolean                        | Platform metadata |
| `pgbouncer_pool_mode`       | string (transaction/session)   | Platform metadata |
| `postgrest_max_rows`        | integer                        | Platform config   |
| `supabase_project_age_days` | integer                        | Platform metadata |

### Supabase-Specific Customer Questions

Add these to the customer-derived intake for Supabase assessments:

- Are you using Supabase Auth, or an external auth provider?
- Do you use Realtime subscriptions? Approximately how many concurrent subscribers?
- Do you use Supabase Storage? Approximately how many files?
- Do you use pgvector? What embedding dimensions?
- Have you customized any RLS policies beyond the defaults?
- Do you have pg_cron jobs? What do they do?

### Supabase Feature Interaction Matrix

Supabase features interact and compound health concerns:

- **PostgREST + RLS** = every API call pays the RLS tax; index coverage on policy columns is critical
- **Realtime + high write volume** = WAL pressure from both logical replication and physical replication
- **Auth + high traffic** = session/token table churn creates vacuum pressure
- **Storage + large file counts** = storage.objects table growth creates maintenance pressure
- **pgvector + large datasets** = memory pressure from HNSW indexes in shared_buffers
