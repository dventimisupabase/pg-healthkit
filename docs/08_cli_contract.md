# CLI Integration Contract

## Purpose

Define the narrow contract between the CLI and the assessment system. The CLI should not need to know the full schema internals. It speaks a constrained set of operations that create, populate, analyze, and retrieve assessments.

## CLI Responsibilities

The CLI has five core responsibilities:

1. **Create assessment** — initialize a new health evaluation
2. **Upsert inputs** — supply platform and customer context
3. **Run probes and upload evidence** — execute SQL probes locally and transmit results
4. **Trigger analysis, scoring, and report generation** — invoke server-side rule evaluation
5. **Fetch summary** — retrieve assessment status, scores, and finding counts

The CLI collects and transmits evidence reliably. That is its core job. Interpretation, scoring, and reporting belong to the server.

## Design Principle

The CLI should be a client of this contract, not a direct schema manipulator. Even if v1 is implemented entirely inside Supabase SQL/Edge Functions, the CLI should behave as if it were calling a formal API. This keeps the boundary clean and allows the server implementation to evolve independently.

## Operation 1: Create Assessment

### Command

```bash
supabase db health init \
  --project-ref <project_ref> \
  --created-by <email-or-handle> \
  --title "Performance review for checkout latency" \
  --profile "performance" \
  --primary-persona "application_developer" \
  --workload-type "oltp"
```

### Request Payload

```json
{
  "project_ref": "abcd1234",
  "created_by": "alice@example.com",
  "title": "Performance review for checkout latency",
  "assessment_profile": "performance",
  "primary_persona": "application_developer",
  "workload_type": "oltp",
  "platform_context": {
    "managed_service": true
  }
}
```

### Response

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "project_ref": "abcd1234",
  "status": "draft",
  "created_at": "2026-03-20T18:42:11Z"
}
```

## Operation 2: Upsert Inputs

The CLI should be able to write inputs independently of assessment creation.

### Single Input

```bash
supabase db health input set \
  --assessment-id <uuid> \
  --source platform \
  --key postgres_version \
  --value '"17.4.1.084"'
```

### Batch Import

```bash
supabase db health input import \
  --assessment-id <uuid> \
  --file inputs.json
```

### Batch Payload

```json
{
  "assessment_id": "uuid",
  "inputs": [
    {
      "key": "postgres_version",
      "value": "17.4.1.084",
      "source": "platform",
      "confidence": "high"
    },
    {
      "key": "extensions",
      "value": ["pg_stat_statements", "pg_cron"],
      "source": "platform",
      "confidence": "high"
    },
    {
      "key": "application_description",
      "value": "Customer-facing transactional API",
      "source": "customer",
      "confidence": "high"
    }
  ]
}
```

### Response

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "upserted": 6
}
```

## Operation 3: Run Probes and Upload Evidence

### Command

```bash
supabase db health probe run \
  --assessment-id <uuid> \
  --profile default \
  --target database \
  --upload
```

The CLI executes probes locally or in the operator environment, then uploads one evidence record per probe.

### Evidence Upload Payload

```json
{
  "assessment_id": "uuid",
  "evidence": [
    {
      "source": "cli_probe",
      "probe_name": "long_running_transactions",
      "probe_version": "2026-03-20",
      "target_scope": "database",
      "status": "success",
      "payload": {
        "columns": ["pid", "usename", "xact_age_seconds", "query"],
        "rows": [
          {
            "pid": 12345,
            "usename": "app",
            "xact_age_seconds": 18420,
            "query": "begin; ..."
          }
        ],
        "summary": {
          "row_count": 1,
          "oldest_xact_age_seconds": 18420
        }
      },
      "metadata": {
        "duration_ms": 11,
        "collector_version": "0.1.0",
        "database_name": "postgres"
      }
    }
  ]
}
```

### Partial Failure Semantics

The CLI should upload partial success cleanly. If 12 probes run and 2 fail, the 10 successful ones should still persist. The 2 failures should also persist as evidence records with `status = "failed"` and `error_text` populated. No probe failure should prevent the remaining evidence from being stored.

### Response

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "accepted": 12,
  "failed": 0
}
```

## Operation 4: Trigger Analysis

Server-side analysis is recommended over CLI-side analysis in v1. This centralizes rule evolution and ensures findings can always be reproduced server-side.

The `analyze` command is safe to re-run. Re-running it after updating customer context (via `input set` or `input import`) triggers the business-context-adjusted scoring pass (Pass 2). See `10_scoring_model.md` for the two-pass scoring model.

### Command

```bash
supabase db health analyze --assessment-id <uuid>
```

### Response

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "findings_created": 7,
  "findings_updated": 2,
  "scores_updated": true,
  "status": "review"
}
```

## Operation 5: Generate Report

### Command

```bash
supabase db health report generate \
  --assessment-id <uuid> \
  --format markdown
```

### Response

```json
{
  "report_id": "uuid",
  "report_type": "markdown"
}
```

## Operation 6: Get Summary

### Command

```bash
supabase db health show --assessment-id <uuid>
```

### Response

```json
{
  "assessment": {
    "id": "uuid",
    "project_ref": "abcd1234",
    "status": "review",
    "primary_persona": "application_developer",
    "workload_type": "oltp",
    "assessment_profile": "performance"
  },
  "scores": {
    "overall_score": 62.5,
    "performance_score": 48.0,
    "concurrency_score": 55.0,
    "storage_score": 71.0
  },
  "finding_counts": {
    "critical": 0,
    "high": 2,
    "medium": 4,
    "low": 3
  }
}
```

## API Shape

Even if a formal public API is not built immediately, the CLI should behave as though one exists. The internal endpoint set:

| Method  | Endpoint                                 | Operation         |
|---------|------------------------------------------|-------------------|
| `POST`  | `/assessments`                           | Create assessment |
| `PATCH` | `/assessments/{id}`                      | Update assessment |
| `POST`  | `/assessments/{id}/inputs:batchUpsert`   | Upsert inputs     |
| `POST`  | `/assessments/{id}/evidence:batchCreate` | Upload evidence   |
| `POST`  | `/assessments/{id}/analyze`              | Trigger analysis  |
| `POST`  | `/assessments/{id}/reports`              | Generate report   |
| `GET`   | `/assessments/{id}`                      | Get summary       |
| `GET`   | `/assessments/{id}/findings`             | List findings     |
| `GET`   | `/assessments/{id}/scores`               | Get scores        |

## Error Response Contract

All error responses use a consistent JSON envelope. The CLI should parse this shape for every non-2xx response.

### Error Envelope

```json
{
  "error": {
    "code": "not_found",
    "message": "Assessment with id 08f0af86-... does not exist.",
    "details": {}
  }
}
```

| Field              | Type   | Description                                                                 |
|--------------------|--------|-----------------------------------------------------------------------------|
| `error.code`       | string | Machine-readable error class (see table below)                              |
| `error.message`    | string | Human-readable description, safe to display to operators                    |
| `error.details`    | object | Optional structured context (e.g., which fields failed validation)          |

### HTTP Status Codes

| Status | When                                                                                     |
|--------|------------------------------------------------------------------------------------------|
| `400`  | Malformed request body, missing required fields, invalid enum values                     |
| `401`  | Missing or invalid authentication credentials                                            |
| `403`  | Authenticated but not authorized for this assessment or operation                        |
| `404`  | Assessment, evidence, or finding ID does not exist                                       |
| `409`  | Conflict — e.g., assessment is in a state that does not allow the requested operation    |
| `422`  | Payload validation failed — evidence does not match probe registry contract              |
| `500`  | Server-side error (rule evaluation failure, database error, unexpected exception)        |

### Error Codes

| Code                       | HTTP Status | Description                                                        |
|----------------------------|-------------|--------------------------------------------------------------------|
| `bad_request`              | 400         | Generic malformed request                                          |
| `missing_field`            | 400         | Required field absent — `details.field` names the missing field    |
| `invalid_value`            | 400         | Field present but invalid — `details.field`, `details.expected`    |
| `unauthorized`             | 401         | Authentication required or credentials invalid                     |
| `forbidden`                | 403         | Caller lacks permission for this resource                          |
| `not_found`                | 404         | Referenced resource does not exist                                 |
| `state_conflict`           | 409         | Operation not valid for current assessment status                  |
| `evidence_validation_failed` | 422       | Evidence payload does not match registry — `details.probe_name`, `details.violations` |
| `analysis_error`           | 500         | Rule evaluation or scoring failed — `details.rule_id` if available |
| `internal_error`           | 500         | Unexpected server error                                            |

### Validation Error Details

For `422` responses from evidence upload, `details` should include enough information to diagnose:

```json
{
  "error": {
    "code": "evidence_validation_failed",
    "message": "Evidence for probe 'long_running_transactions' failed contract validation.",
    "details": {
      "probe_name": "long_running_transactions",
      "violations": [
        { "field": "summary.oldest_xact_age_seconds", "expected": "number", "actual": "string" }
      ]
    }
  }
}
```

### CLI Behavior on Errors

The CLI should:
- Display `error.message` to the operator on any non-2xx response
- Exit with a non-zero status code
- Log `error.code` and `error.details` at debug verbosity for troubleshooting
- Not retry on 4xx errors (client's fault); optionally retry once on 5xx with backoff

## Authentication and Authorization

### Authentication Model

The CLI authenticates to the Arena using **Supabase service-role keys**. This is the simplest viable model for v1, consistent with how the Supabase CLI already authenticates to Management API endpoints.

| Component     | Credential                | How Obtained                                              |
|---------------|---------------------------|-----------------------------------------------------------|
| CLI → Arena   | Supabase service-role JWT | From the Arena project's API settings or `SUPABASE_SERVICE_ROLE_KEY` env var |
| Arena → DB    | Postgres connection       | Internal to the Supabase project (automatic)              |

The CLI sends the service-role key in the `Authorization` header:

```
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
```

> **Why service-role, not anon key?** The Arena stores assessment data that should not be publicly accessible. The anon key's RLS policies would require per-assessment row-level rules that add complexity without clear benefit in v1. The service-role key bypasses RLS, which is acceptable because the CLI is an operator tool, not a customer-facing application.

### Authorization Model

For v1, authorization is coarse-grained:

| Principal          | Access Level                                           |
|--------------------|--------------------------------------------------------|
| Service-role CLI   | Full read/write to all assessments within the Arena project |
| Authenticated user (future) | Scoped to assessments they created or are assigned to |

The service-role key grants full access. This is appropriate for v1 because:
- The CLI is run by internal operators, not external customers
- The Arena project is an internal tool, not a customer-facing application
- Assessment data is not multi-tenant in v1

### Future Considerations

When the system matures to support multiple operators or customer-visible dashboards:

1. **Per-operator auth** — Use Supabase Auth with user JWTs. Add `created_by` and `assigned_to` checks via RLS policies on the `assessments` table.
2. **Organization scoping** — Use `organization_ref` on assessments to scope access by org. RLS policies would enforce `auth.jwt() ->> 'org_id' = organization_ref`.
3. **Read-only customer access** — Expose a read-only view of completed assessments to customers via the anon key with RLS policies restricting to `status = 'completed'` and matching `project_ref`.

These are not v1 requirements but the data model already has the fields (`created_by`, `assigned_to`, `organization_ref`) to support them.

### Credential Management

The CLI should resolve credentials in this order:

1. `--service-role-key` flag (explicit, highest priority)
2. `SUPABASE_SERVICE_ROLE_KEY` environment variable
3. Linked project credentials from `supabase link` (if integrated into the Supabase CLI)

If no credentials are available, the CLI should fail with a clear error message before attempting any API call.

## State Transitions

Assessment lifecycle:

```
draft
  -> intake_in_progress      (once contextual inputs begin)
    -> evidence_in_progress   (once probes start)
      -> analysis_in_progress (when findings/scoring run)
        -> review             (when human review starts)
          -> completed        (when report is final)
            -> archived       (if superseded or closed)
```

| State                  | Entered When            |
|------------------------|-------------------------|
| `draft`                | Assessment is created   |
| `intake_in_progress`   | Contextual inputs begin |
| `evidence_in_progress` | Probes start            |
| `analysis_in_progress` | Findings/scoring run    |
| `review`               | Human review starts     |
| `completed`            | Report is final         |
| `archived`             | Superseded or closed    |

Do not over-enforce state transitions in v1. Logging events is enough.

## Findings Contract

A finding should be stable, explainable, and deduplicatable. The `finding_key` represents the rule or issue class, not the exact title text.

### Minimal Finding Payload

```json
{
  "finding_key": "long_running_transactions",
  "domain": "concurrency",
  "severity": "high",
  "title": "Long-running transactions detected",
  "summary": "Transactions older than 1 hour were present during evidence collection.",
  "cause_text": "Application transaction boundaries are too broad, or sessions are being abandoned without rollback.",
  "impact_text": "These transactions can delay vacuum progress, increase bloat, and contribute to lock contention.",
  "recommendation_text": "Review application transaction boundaries and identify abandoned sessions.",
  "urgency": "short_term",
  "evidence_refs": [
    {
      "probe_name": "long_running_transactions",
      "evidence_id": "uuid"
    }
  ],
  "rule_metadata": {
    "threshold_seconds": 3600,
    "observed_oldest_seconds": 18420
  },
  "confidence": "high"
}
```

## Score Contract

Scoring payloads should be transparent. Do not hide scoring logic behind a single opaque number.

### Score Payload

```json
{
  "scoring_profile": "default",
  "availability_score": 78,
  "performance_score": 48,
  "concurrency_score": 55,
  "storage_score": 71,
  "efficiency_score": 64,
  "cost_score": 59,
  "operational_hygiene_score": 80,
  "overall_score": 62.5,
  "score_payload": {
    "weights": {
      "availability": 0.2,
      "performance": 0.2,
      "concurrency": 0.15,
      "storage": 0.15,
      "operational_hygiene": 0.1,
      "efficiency": 0.1,
      "cost": 0.1
    },
    "rationale": [
      "Performance score reduced due to top query latency and temp spill activity.",
      "Concurrency score reduced due to long-running transactions and observed blockers."
    ]
  }
}
```

## Go CLI Command Surface

The v1 command surface:

| Command                              | Purpose                                  |
|--------------------------------------|------------------------------------------|
| `supabase db health init`            | Create a new assessment                  |
| `supabase db health input set`       | Set a single input                       |
| `supabase db health input import`    | Batch import inputs from file            |
| `supabase db health probe run`       | Execute probes and upload evidence       |
| `supabase db health analyze`         | Trigger server-side analysis and scoring |
| `supabase db health report generate` | Generate a report                        |
| `supabase db health show`            | Display assessment summary               |
| `supabase db health findings list`   | List findings for an assessment          |

## Example Flow

End-to-end command sequence:

```bash
# 1. Create assessment
supabase db health init \
  --project-ref abcd1234 \
  --created-by alice@example.com \
  --title "Q1 health assessment"

# 2. Import customer context
supabase db health input import \
  --assessment-id <uuid> \
  --file customer-context.json

# 3. Run probes and upload evidence
supabase db health probe run \
  --assessment-id <uuid> \
  --profile default \
  --upload

# 4. Trigger analysis
supabase db health analyze \
  --assessment-id <uuid>

# 5. Generate report
supabase db health report generate \
  --assessment-id <uuid> \
  --format markdown
```

## Suggested Directory Structure

```
pg_healthkit/
  probes/
    00_instance_metadata.sql
    01_extensions_inventory.sql
    ...
  cli/
    main.go
    db.go
    runner.go
    normalize.go
  arena/
    supabase/
      migrations/       # schema
      functions/         # rule evaluation, scoring, reporting
  contracts/
    probe_registry.yaml
    rules.yaml
  docs/
    01_methodology.md
    ...
```

SQL probes are stored as versioned files. The CLI handles probe execution and normalization. Rule evaluation, scoring, and reporting live in Arena SQL functions. Contracts (YAML) define the boundary between components.

## What the CLI Should NOT Do in v1

Avoid putting too much business logic into the CLI. Specifically:

- **No system of record.** The CLI should not be the authoritative store for assessment state. The server owns state.
- **No embedded large rule sets.** Rules should live server-side so they can evolve without CLI releases.
- **No findings generation that cannot be reproduced server-side.** If the CLI generates findings locally, the same logic must also exist on the server.
- **No tight coupling of probe format to report format.** Evidence payloads and report rendering are separate concerns with independent evolution.

The CLI collects and transmits evidence reliably. That is its core job.
