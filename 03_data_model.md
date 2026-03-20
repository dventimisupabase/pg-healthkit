# Data Model

## Design Principles

1. **Distinguish data types.** Platform facts, customer assertions, derived findings, and human judgments live in separate structures.
2. **Append-only evidence.** Probe results are observations. Re-runs produce new records, not overwrites.
3. **Separate rule outputs from raw evidence.** Raw evidence remains inspectable independently.
4. **Allow partial completion.** Assessments are valid even with missing evidence.
5. **JSONB for variable payloads.** Relational structure for core entities; JSONB where payloads vary.

## Schema

### Enum Types

```sql
create extension if not exists pgcrypto;

create type assessment_status as enum (
  'draft',
  'intake_in_progress',
  'evidence_in_progress',
  'analysis_in_progress',
  'review',
  'completed',
  'archived'
);

create type input_source as enum (
  'platform',
  'customer',
  'operator',
  'derived'
);

create type evidence_source as enum (
  'cli_probe',
  'platform_api',
  'manual_entry',
  'imported'
);

create type finding_severity as enum (
  'info',
  'low',
  'medium',
  'high',
  'critical'
);

create type finding_status as enum (
  'open',
  'accepted',
  'dismissed',
  'resolved'
);
```

### assessments

The lifecycle object. Stores enough top-level context to list, filter, and reason about assessments.

```sql
create table assessments (
  id uuid primary key default gen_random_uuid(),
  project_ref text not null,
  organization_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by text not null,
  assigned_to text,
  status assessment_status not null default 'draft',

  title text,
  objective text,
  primary_persona text,
  workload_type text,
  assessment_profile text not null default 'default',

  platform_context jsonb not null default '{}'::jsonb,
  customer_context jsonb not null default '{}'::jsonb,

  started_at timestamptz,
  completed_at timestamptz,

  tags text[] not null default '{}'
);

create index assessments_project_ref_idx on assessments(project_ref);
create index assessments_status_idx on assessments(status);
create index assessments_created_at_idx on assessments(created_at desc);
```

Example `platform_context`:

```json
{
  "postgres_version": "17.4.1.084",
  "managed_service": true,
  "region": "us-east-1",
  "compute_tier": "medium",
  "pitr_enabled": true,
  "replica_count": 2
}
```

### assessment_inputs

Normalized key/value inputs with provenance. Unlike `platform_context` / `customer_context` (which are convenient denormalized snapshots), this table gives you source-aware assertions with queryability.

```sql
create table assessment_inputs (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  key text not null,
  value jsonb not null,
  source input_source not null,
  confidence text,
  collected_at timestamptz not null default now(),
  collected_by text,
  notes text,

  unique (assessment_id, key, source)
);

create index assessment_inputs_assessment_id_idx on assessment_inputs(assessment_id);
create index assessment_inputs_key_idx on assessment_inputs(key);
```

Example rows:

| key | value | source |
|-----|-------|--------|
| `postgres_version` | `"17.4.1.084"` | platform |
| `managed_service` | `true` | platform |
| `workload_type` | `"oltp"` | customer |
| `primary_objective` | `"latency reduction"` | customer |

The duplication between `assessment_inputs` and `platform_context`/`customer_context` is acceptable in v1: one is optimized for convenience, one for traceability.

### assessment_evidence

Raw probe outputs and imported telemetry. JSONB is the correct choice because probe payloads vary.

```sql
create table assessment_evidence (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  source evidence_source not null,
  probe_name text not null,
  probe_version text,
  collected_at timestamptz not null default now(),
  collected_by text,

  target_scope text not null default 'database',
  status text not null default 'success',

  payload jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  error_text text
);

create index assessment_evidence_assessment_id_idx on assessment_evidence(assessment_id);
create index assessment_evidence_probe_name_idx on assessment_evidence(probe_name);
create index assessment_evidence_collected_at_idx on assessment_evidence(collected_at desc);
```

### assessment_findings

The interpreted result. This is what humans act on.

```sql
create table assessment_findings (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  finding_key text not null,
  domain text not null,
  severity finding_severity not null,
  status finding_status not null default 'open',

  title text not null,
  summary text not null,
  impact_text text,
  recommendation_text text,

  evidence_refs jsonb not null default '[]'::jsonb,
  rule_metadata jsonb not null default '{}'::jsonb,

  confidence text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by text not null,
  reviewed_by text,

  unique (assessment_id, finding_key)
);

create index assessment_findings_assessment_id_idx on assessment_findings(assessment_id);
create index assessment_findings_domain_idx on assessment_findings(domain);
create index assessment_findings_severity_idx on assessment_findings(severity);
```

### assessment_scores

Computed rollup. Scoring payloads should be transparent.

```sql
create table assessment_scores (
  assessment_id uuid primary key references assessments(id) on delete cascade,
  scoring_profile text not null default 'default',
  computed_at timestamptz not null default now(),

  availability_score numeric(5,2),
  performance_score numeric(5,2),
  concurrency_score numeric(5,2),
  storage_score numeric(5,2),
  efficiency_score numeric(5,2),
  cost_score numeric(5,2),

  overall_score numeric(5,2),
  score_payload jsonb not null default '{}'::jsonb
);
```

Example `score_payload`:

```json
{
  "weights": {
    "availability": 0.2,
    "performance": 0.25,
    "concurrency": 0.2,
    "storage": 0.15,
    "efficiency": 0.1,
    "cost": 0.1
  },
  "rationale": [
    "Performance score reduced due to top query latency and temp spill activity.",
    "Concurrency score reduced due to long-running transactions and observed blockers."
  ]
}
```

### assessment_reports

Generated artifacts. Store both structured and narrative output for future portability.

```sql
create table assessment_reports (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  report_type text not null,
  report_version text,
  created_at timestamptz not null default now(),
  created_by text not null,

  content_markdown text,
  content_json jsonb,
  metadata jsonb not null default '{}'::jsonb
);

create index assessment_reports_assessment_id_idx on assessment_reports(assessment_id);
```

### assessment_events

Cheap audit trail and workflow history without fully modeling workflow upfront.

```sql
create table assessment_events (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  event_type text not null,
  event_time timestamptz not null default now(),
  actor text not null,
  payload jsonb not null default '{}'::jsonb
);

create index assessment_events_assessment_id_idx on assessment_events(assessment_id);
create index assessment_events_event_time_idx on assessment_events(event_time desc);
```

## platform_context vs assessment_inputs

Use `platform_context` on assessments for convenient denormalized display and filtering.

Use `assessment_inputs` for source-aware assertions with queryability and provenance.

Both exist because:
- `platform_context` is optimized for convenience (filter, display, quick access)
- `assessment_inputs` is optimized for traceability (who said what, from where, when)

## State Transitions

Do not over-enforce in v1. Logging events is enough.

```
draft → intake_in_progress → evidence_in_progress → analysis_in_progress → review → completed → archived
```

Typical path:
- `draft` when assessment is created
- `intake_in_progress` once contextual inputs begin
- `evidence_in_progress` once probes start
- `analysis_in_progress` when findings/scoring run
- `review` when human review starts
- `completed` when report is final
- `archived` if superseded or closed
