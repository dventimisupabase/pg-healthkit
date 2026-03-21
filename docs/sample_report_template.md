# PostgreSQL Health Assessment Report

## 1. Assessment Overview

- **Assessment ID:** {{assessment_id}}
- **Generated At:** {{generated_at}}
- **Database:** {{database_name}}
- **PostgreSQL Version:** {{postgres_version}}
- **Environment Type:** {{environment_type}}  <!-- managed | self-hosted -->
- **Workload Type:** {{workload_type}}        <!-- oltp | olap | hybrid -->
- **Profile:** {{assessment_profile}}

---

## 2. Executive Summary

### Overall Health Score: **{{overall_score}} / 100**

{{overall_summary}}

### Top Findings

{{#top_findings}}
- **{{severity}}** — {{title}}
  - {{summary}}
{{/top_findings}}

### Risk Posture

| Domain         | Score |
|----------------|------:|
| Availability   | {{scores.availability}} |
| Performance    | {{scores.performance}} |
| Concurrency    | {{scores.concurrency}} |
| Storage        | {{scores.storage}} |
| Efficiency     | {{scores.efficiency}} |
| Cost           | {{scores.cost}} |
| Operational Hygiene | {{scores.operational_hygiene}} |

---

## 3. Findings (Detailed)

{{#findings_by_domain}}

### {{domain}}

{{#findings}}

#### {{title}}

- **Severity:** {{severity}}
- **Confidence:** {{confidence}}
- **Finding Key:** `{{key}}`
- **Tags:** {{tags}}

**Summary**  
{{summary}}

**Impact**  
{{impact}}

**Recommendation**  
{{recommendation}}

**Evidence**
{{#evidence_refs}}
- Probe: `{{probe_name}}`
- Key Signals:
  {{#signals}}
  - {{.}}
  {{/signals}}
{{/evidence_refs}}

---

{{/findings}}

{{/findings_by_domain}}

---

## 4. Action Plan

### Immediate (Critical / High Findings)

{{#action_plan.immediate}}
- **{{action}}**
  - Addresses: `{{finding_key}}` ({{severity}})
  - Tradeoffs: {{tradeoffs}}
{{/action_plan.immediate}}

### Short-term (Medium Findings)

{{#action_plan.short_term}}
- **{{action}}**
  - Addresses: `{{finding_key}}` ({{severity}})
  - Tradeoffs: {{tradeoffs}}
{{/action_plan.short_term}}

### Structural (Low Findings / Improvements)

{{#action_plan.structural}}
- **{{action}}**
  - Addresses: `{{finding_key}}` ({{severity}})
  - Tradeoffs: {{tradeoffs}}
{{/action_plan.structural}}

---

## 5. Domain Score Detail

{{#domain_scores}}

### {{domain}} — **{{score}} / 100** ({{risk_level}})

| Finding | Severity | Score Delta |
|---------|----------|------------:|
{{#contributing_findings}}
| {{title}} (`{{key}}`) | {{severity}} | {{score_delta}} |
{{/contributing_findings}}

{{/domain_scores}}

---

## 6. Supporting Observations

### Top Queries (by Total Time)
{{#top_queries_total_time}}
- Query ID: {{queryid}}
  - Calls: {{calls}}
  - Total Time (ms): {{total_exec_time_ms}}
  - Mean Time (ms): {{mean_exec_time_ms}}
{{/top_queries_total_time}}

### Top Queries (by Mean Latency)
{{#top_queries_mean_latency}}
- Query ID: {{queryid}}
  - Calls: {{calls}}
  - Mean Time (ms): {{mean_exec_time_ms}}
{{/top_queries_mean_latency}}

### Largest Tables
{{#largest_tables}}
- {{schemaname}}.{{relname}}
  - Total Size (bytes): {{total_bytes}}
{{/largest_tables}}

---

## 7. Interpretation Notes

- Scores are initialized at 100 and reduced by rule-based deductions.
- Severity reflects operational impact; confidence reflects evidence reliability.
- Absence of findings does not imply absence of risk; some probes may be skipped.
- Workload type influences interpretation (e.g., latency thresholds differ for OLTP vs OLAP).

---

## 8. Methodology Reference

This report is generated using:

- Probe-based evidence collection
- Deterministic normalization contracts
- Rule-based evaluation (`rules.yaml`)
- Domain-based scoring model

For details, refer to:
- `docs/09_rule_engine.md`
- `contracts/probe_registry.yaml`
- `docs/15_normalizer.md`

---

## 9. Appendix: Probe Execution Summary

| Probe Name | Status | Notes |
|------------|--------|-------|
{{#probe_status}}
| {{name}} | {{status}} | {{note}} |
{{/probe_status}}
