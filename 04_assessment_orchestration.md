# Assessment Orchestration

## Purpose
Defines the workflow ("arena") for assessments.

## Lifecycle
1. create
2. input context
3. collect metadata
4. run probes
5. normalize
6. evaluate rules
7. score
8. report
9. iterate

## System
Postgres-backed store of:
- assessments
- inputs
- evidence
- findings
- scores

## Interfaces
- CLI
- web UI (future)
- Slack (future)

## Principle
This is a workflow system, not just a CLI.