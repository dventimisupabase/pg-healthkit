# CLI Contract

## Design Principle

The CLI should be a **client** of a narrow contract, not a direct schema manipulator. Even if v1 does not have a formal API service, define it as if it did. That keeps the CLI clean.

The CLI's core job is to **collect and transmit evidence reliably**. Business logic (rules, scoring, reporting) should live server-side where practical.

## Command Surface

```
supabase db health init
supabase db health input set
supabase db health input import
supabase db health probe run
supabase db health analyze
supabase db health report generate
supabase db health show
supabase db health findings list
```

## Operations

### Operation 1: Create Assessment (`init`)

```bash
supabase db health init \
  --project-ref <project_ref> \
  --created-by <email-or-handle> \
  --title "Performance review for checkout latency" \
  --objective "performance" \
  --primary-persona "application_developer" \
  --workload-type "oltp"
```

**Request payload:**

```json
{
  "project_ref": "abcd1234",
  "created_by": "alice@example.com",
  "title": "Performance review for checkout latency",
  "objective": "performance",
  "primary_persona": "application_developer",
  "workload_type": "oltp",
  "platform_context": {
    "managed_service": true
  }
}
```

**Response:**

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "project_ref": "abcd1234",
  "status": "draft",
  "created_at": "2026-03-20T18:42:11Z"
}
```

### Operation 2: Upsert Single Input (`input set`)

```bash
supabase db health input set \
  --assessment-id <uuid> \
  --source platform \
  --key postgres_version \
  --value '"17.4.1.084"'
```

### Operation 3: Batch Import Inputs (`input import`)

```bash
supabase db health input import \
  --assessment-id <uuid> \
  --file inputs.json
```

**Batch payload:**

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

**Response:**

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "upserted": 6
}
```

### Operation 4: Run Probes and Upload Evidence (`probe run`)

```bash
supabase db health probe run \
  --assessment-id <uuid> \
  --profile default \
  --target database \
  --upload
```

The CLI executes probes locally (or in the operator environment), then uploads one evidence record per probe.

**Evidence upload payload:**

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

**Response:**

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "accepted": 12,
  "failed": 0
}
```

**Partial success handling:** If 12 probes run and 2 fail, the 10 successful ones should persist, and the 2 failures should also persist as evidence records with `status = failed` and `error_text` populated.

### Operation 5: Trigger Analysis (`analyze`)

```bash
supabase db health analyze --assessment-id <uuid>
```

For v1, server-side analysis is recommended (even if implemented simply) because it centralizes rule evolution.

**Response:**

```json
{
  "assessment_id": "08f0af86-bc93-4d38-8b31-bf4d9ef48d66",
  "findings_created": 7,
  "findings_updated": 2,
  "scores_updated": true,
  "status": "review"
}
```

### Operation 6: Generate Report (`report generate`)

```bash
supabase db health report generate \
  --assessment-id <uuid> \
  --format markdown
```

**Response:**

```json
{
  "report_id": "uuid",
  "report_type": "markdown"
}
```

### Operation 7: Show Assessment Summary (`show`)

```bash
supabase db health show --assessment-id <uuid>
```

**Response:**

```json
{
  "assessment": {
    "id": "uuid",
    "project_ref": "abcd1234",
    "status": "review",
    "primary_persona": "application_developer",
    "workload_type": "oltp",
    "objective": "performance"
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

### Operation 8: List Findings (`findings list`)

```bash
supabase db health findings list --assessment-id <uuid>
```

## API Endpoints

Even without a formal public API, define it as if you had one:

| Method  | Path                                     | Purpose                             |
|---------|------------------------------------------|-------------------------------------|
| `POST`  | `/assessments`                           | Create assessment                   |
| `PATCH` | `/assessments/{id}`                      | Update assessment metadata/status   |
| `POST`  | `/assessments/{id}/inputs:batchUpsert`   | Upsert inputs                       |
| `POST`  | `/assessments/{id}/evidence:batchCreate` | Upload probe evidence               |
| `POST`  | `/assessments/{id}/analyze`              | Trigger rule evaluation and scoring |
| `POST`  | `/assessments/{id}/reports`              | Generate report                     |
| `GET`   | `/assessments/{id}`                      | Get assessment summary              |
| `GET`   | `/assessments/{id}/findings`             | List findings                       |
| `GET`   | `/assessments/{id}/scores`               | Get scores                          |

## State Transitions

```
draft
  → intake_in_progress    (once inputs begin)
    → evidence_in_progress (once probes start)
      → analysis_in_progress (when analyze runs)
        → review           (when human review starts)
          → completed      (when report is final)
            → archived     (if superseded)
```

## Example End-to-End Flow

```bash
# Create assessment
supabase db health init \
  --project-ref abcd1234 \
  --created-by alice@example.com \
  --title "Q1 health assessment"

# Import customer context
supabase db health input import \
  --assessment-id <uuid> \
  --file customer-context.json

# Run probes
supabase db health probe run \
  --assessment-id <uuid> \
  --profile oltp \
  --upload

# Analyze
supabase db health analyze \
  --assessment-id <uuid>

# Generate report
supabase db health report generate \
  --assessment-id <uuid> \
  --format markdown
```

## What the CLI Should NOT Do in v1

- **Be the system of record** — the database is the system of record
- **Embed large rule sets only in the CLI** — rules should be server-side or loaded from contracts
- **Generate findings in a way that cannot be reproduced server-side** — findings should be deterministic from stored evidence
- **Tightly couple probe execution format to report rendering format** — keep these layers separate

## Implementation Language

For Supabase, Go is the natural choice — not because Go is intrinsically superior for this problem, but because organizational fit matters. The Supabase CLI already exists in Go with an early inspection component. The health audit should be a new subcommand or module backed by reusable Go packages with SQL probes stored as versioned assets and rule evaluation implemented in Go.
