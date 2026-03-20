# Cross-Assessment Model

## Purpose

Enable comparison and learning across multiple assessments. Once assessments are stored structurally, you unlock something more valuable than individual reports.

## Strategic Value

### Cross-customer benchmarking
Compare patterns across workloads and database sizes. Establish baselines for what "normal" looks like for a given workload type and instance size.

### Pattern detection
Identify systemic issues across the customer base. Example: "80% of customers on the medium tier have autovacuum issues" or "Multi-tenant SaaS workloads consistently show high idle-in-transaction sessions."

### Product feedback loops
Assessment data reveals what Supabase should fix at the **platform level**, not just the customer level. If the same finding appears across many customers, it may indicate a default configuration issue, a missing platform feature, or a documentation gap.

### Automated recommendations over time
Historical assessments create a learning dataset. Future assessments can reference typical baselines, expected score ranges, and common remediation paths for similar workloads.

## Comparison Axes

| Axis                    | What It Enables                                       |
|-------------------------|-------------------------------------------------------|
| **Workload type**       | Compare OLTP vs OLAP vs hybrid baselines              |
| **Database size**       | Normalize findings by data volume                     |
| **Instance tier**       | Compare performance relative to provisioned resources |
| **Score distributions** | Identify outliers and typical ranges per domain       |
| **Finding frequency**   | Which issues are most common across the fleet         |
| **Temporal trends**     | How a single customer's health evolves over time      |

## Capabilities by Maturity

### Near-term (after v1 persistence)
- Compare two assessments for the same project (before/after)
- Aggregate finding counts across all assessments
- Identify the most common findings fleet-wide

### Medium-term
- Score distribution histograms by workload type
- Baseline ranges ("typical OLTP performance score: 65–85")
- Anomaly detection ("this database's concurrency score is 2 standard deviations below fleet average")

### Long-term
- Recommendation engine informed by historical outcomes
- Predictive alerts ("databases with this pattern typically experience incidents within 30 days")
- Platform improvement prioritization based on fleet-wide signal

## Constraints

### Anonymization
Cross-customer analysis must respect privacy boundaries. Aggregated statistics can be shared; individual customer evidence cannot.

### Normalization
Comparisons are only meaningful if scoring and normalization are stable. If scoring weights or rule thresholds change, historical comparisons may be invalid unless version-aware.

### Stable scoring required
Cross-assessment comparison depends on:
- Stable domain definitions
- Stable rule IDs and thresholds
- Stable probe contracts
- Versioned scoring profiles

If any of these change, the comparison must account for the version difference.

### Sample size
Fleet-wide patterns require sufficient assessment volume. Early conclusions from small samples should be flagged as low-confidence.

## Architectural Implications

The single-assessment design should not prevent cross-assessment queries. Specifically:

- `assessment_scores` should be queryable across assessments (already true with the schema in `03_data_model.md`)
- `assessment_findings` should be groupable by `finding_key` across assessments
- Assessment metadata should include enough context (workload_type, instance tier, project_ref) to enable meaningful grouping

No additional schema is required in v1, but the system should be **aware** that multi-assessment queries are a future capability. Avoid design decisions that would make cross-assessment analysis difficult later.

## Why This Matters Now

Even though cross-assessment capabilities are not in v1, acknowledging the model now:

1. **Prevents architectural dead ends** — single-assessment-scoped design would box the system in
2. **Informs schema decisions** — e.g., keeping `finding_key` stable and meaningful
3. **Motivates persistence** — if assessments are not stored, cross-assessment analysis is impossible
4. **Frames the product potential** — this is where the system becomes strategically important, not just operationally useful

## Principle

> More data → better insights. But only if normalization and scoring are stable.
