# Report Template

## Purpose

The report template defines the **presentation contract** — how findings, scores, and evidence become something a human can consume and act on.

Without a template:

- Different implementations or agents structure reports differently
- Findings render inconsistently
- Comparisons across runs become harder
- The "last mile" from evidence to decision is ad hoc

The template answers: what sections exist, in what order, what level of detail is expected, and how findings map to narrative.

## Why This Matters

The system up to this point produces:

- Evidence (probes → normalization)
- Interpretation (rules → findings)
- Scoring (domain scores → overall score)

The report template is where those become operationally useful. It bridges machine output to human decision-making.

## Report Sections

Every assessment report follows this structure:

### 1. Assessment Overview

Assessment metadata: ID, timestamp, database, PostgreSQL version, environment type, workload type, assessment profile.

### 2. Executive Summary

- **Overall health score** (composite)
- **Top findings** — the 3–5 highest-severity findings with one-line summaries
- **Risk posture** — domain scores in a scannable table

This section is persona-specific. A DBA sees availability and concurrency emphasized. A CTO sees cost and efficiency.

### 3. Findings (Detailed)

Grouped by health domain (availability, performance, concurrency, storage, efficiency, cost, operational hygiene).

For each finding:

- **Title** — from `finding.title`
- **Severity** — from matched rule case
- **Confidence** — how trustworthy the inference is
- **Finding Key** — stable identifier (`finding.key`)
- **Tags** — classification labels
- **Summary** — what was observed (rendered from `summary_template`)
- **Impact** — why it matters (rendered from `impact_template`)
- **Recommendation** — what to do (rendered from `recommendation_template`)
- **Evidence** — probe references and key signals

This maps directly to the `finding` block in `rules.yaml`. No translation layer is needed.

### 4. Supporting Observations

Raw high-signal data that provides context but is not a finding:

- Top queries by total time
- Top queries by mean latency
- Largest tables

This section separates interpreted findings from raw data, preventing reports from drowning in metrics or hiding important context.

### 5. Interpretation Notes

Caveats that frame how to read the report:

- Scores start at 100 and are reduced by rule deductions
- Severity reflects operational impact; confidence reflects evidence reliability
- Absence of findings does not imply absence of risk (some probes may be skipped)
- Workload type influences interpretation

### 6. Methodology Reference

Pointers to the underlying system: probe-based evidence, normalization contracts, rule-based evaluation, domain scoring.

### 7. Appendix: Probe Execution Summary

Table of all probes with their execution status (`success`, `skipped`, `failed`) and notes. This makes it clear what evidence was and was not available.

## Template Syntax

The template uses `{{...}}` placeholder syntax for simple values and `{{#...}}` / `{{/...}}` for iteration blocks. This is compatible with:

- Go `text/template` or `html/template`
- Mustache-style renderers
- Agent-generated rendering logic

Example:

```
{{#findings_by_domain}}
### {{domain}}
{{#findings}}
#### {{title}}
- **Severity:** {{severity}}
{{/findings}}
{{/findings_by_domain}}
```

## Alignment with Data Model

| Report Section         | Data Source                          |
|------------------------|--------------------------------------|
| Assessment Overview    | `assessments` table metadata         |
| Executive Summary      | `assessment_scores` + top findings   |
| Findings (Detailed)    | `assessment_findings` grouped by domain |
| Supporting Observations| `assessment_evidence` (raw payloads) |
| Probe Execution Summary| `assessment_evidence` (status field) |

## Design Decisions

**Findings grouped by domain, not by severity.** This keeps the report organized around health areas rather than creating a flat severity list that loses structural context.

**Supporting observations separated from findings.** This prevents the common failure mode where reports either drown in raw data or hide important context.

**Probe execution summary included.** Transparency about what was and was not observed is critical for trust. A report that silently omits skipped probes implies completeness it does not have.

**Template syntax is declarative.** This makes the report renderable by Go templates, CLI tools, or agents without requiring a specific rendering engine.

## Canonical Template

See `docs/sample_report_template.md` for the complete template with all placeholders.
