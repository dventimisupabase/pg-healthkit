# Scoring Model

## Purpose

Translate findings and evidence into a structured, communicable health posture. Scores are a communication device, not science. Do not overfit numeric precision.

## Domains

Seven orthogonal scoring domains:

| Domain                | What It Captures                                                     |
|-----------------------|----------------------------------------------------------------------|
| `availability`        | Uptime, failover readiness, replication health, backup posture       |
| `performance`         | Query latency, throughput, plan quality, I/O efficiency              |
| `concurrency`         | Lock contention, connection pressure, transaction hygiene            |
| `storage`             | Bloat, dead tuples, table/index growth, maintenance posture          |
| `efficiency`          | Resource utilization, temp spill, checkpoint behavior, waste         |
| `cost`                | Right-sizing, storage waste, compute headroom, forecast clarity      |
| `operational_hygiene` | Vacuum/analyze cadence, diagnostic visibility, configuration posture |

## Scale

Each domain scored 0–100, or `null` for unknown.

> **Design note:** The original conversation proposed a 0–5 scale (5=healthy, 4=minor issues, 3=moderate concern, 2=high concern, 1=critical risk, 0=unknown/insufficient evidence). The 0–100 scale was adopted instead because it allows finer-grained score deltas from individual rules without rounding effects, and maps more naturally to percentage-based weighted composites. The original "0 = insufficient evidence" semantics are preserved via `null`.

| Score Range | Interpretation                               |
|-------------|----------------------------------------------|
| 90–100      | Healthy — no significant issues              |
| 70–89       | Minor issues — worth monitoring              |
| 50–69       | Moderate concern — action recommended        |
| 25–49       | High concern — near-term action needed       |
| 0–24        | Critical risk — immediate attention required |
| `null`      | Unknown — insufficient evidence              |

### Unknown / Insufficient Evidence

A domain score of `null` means no probes contributing to that domain produced usable evidence. This is distinct from a score of 100 (healthy). A score of 100 means "we checked and found no issues." A score of `null` means "we could not check."

This distinction matters operationally:
- A domain with `null` should display as "Unknown" or "N/A" in reports, not as healthy
- The overall composite score should exclude `null` domains from the weighted average (reweight across scored domains only)
- The `diagnostic_visibility_limited` finding should be raised when key domains are unscorable due to missing evidence
- Probes that were skipped or failed contribute to `null` domains; probes that ran successfully and found nothing contribute to high scores

## Scoring Mechanism

### v1 Implementation

1. Initialize each domain score to **100** if at least one contributing probe succeeded, or **null** if no contributing probes ran
2. Apply all matched rule deltas (additive, negative)
3. Clamp each final domain score to **0–100** (null domains remain null)
4. Compute overall score from **weighted** domain scores, excluding null domains and redistributing their weight proportionally across scored domains
5. Weights are determined by the assessment profile

The rule engine applies score_effects per matched rule case. See `rules.yaml` for the specific deltas.

### Example

If two rules match:
- `long_running_transactions_detected` (high): concurrency -20, storage -10, availability -8
- `active_lock_blocking_detected` (medium): concurrency -12, performance -6, availability -3

Resulting domain scores:
- concurrency: 100 - 20 - 12 = 68
- storage: 100 - 10 = 90
- availability: 100 - 8 - 3 = 89
- performance: 100 - 6 = 94

## Persona-Specific Weights

Scoring weights vary by assessment profile (which derives from persona):

### DBA / SRE Profile (`reliability`)

| Domain                        | Weight |
|-------------------------------|--------|
| Availability & Recoverability | 25%    |
| Concurrency & Contention      | 20%    |
| Storage & Maintenance         | 20%    |
| Performance & Latency         | 15%    |
| Efficiency & Sizing           | 10%    |
| Operational Hygiene           | 10%    |

### CTO / Eng Leadership Profile (`cost_capacity`)

| Domain                | Weight |
|-----------------------|--------|
| Cost & Capacity       | 30%    |
| Efficiency & Sizing   | 25%    |
| Performance & Latency | 15%    |
| Storage & Maintenance | 15%    |
| Availability          | 10%    |
| Concurrency           | 5%     |

### App Developer Profile (`performance`)

| Domain                   | Weight |
|--------------------------|--------|
| Performance & Latency    | 30%    |
| Concurrency & Contention | 25%    |
| Efficiency               | 15%    |
| Availability             | 15%    |
| Storage                  | 10%    |
| Cost                     | 5%     |

### Default Profile

| Domain       | Weight |
|--------------|--------|
| Availability | 20%    |
| Performance  | 25%    |
| Concurrency  | 20%    |
| Storage      | 15%    |
| Efficiency   | 10%    |
| Cost         | 10%    |

## Two-Pass Scoring

### Pass 1: Technical Baseline

Based only on observable platform and SQL evidence. No customer context required. Produces a draft health profile that can be precomputed before the customer conversation.

### Pass 2: Business-Context-Adjusted

Reweighted after understanding workload and objectives. The evidence stays the same; the interpretation changes.

Example: high temp spill may be "medium severity" in the baseline but "low severity" after the customer confirms it's a nightly analytics job with no latency requirement.

## Score Payload

Scores should be transparent, not opaque. The score payload includes weights, rationale, and per-domain breakdown:

```json
{
  "scoring_profile": "oltp_default",
  "availability_score": 78,
  "performance_score": 48,
  "concurrency_score": 55,
  "storage_score": 71,
  "efficiency_score": 64,
  "cost_score": 59,
  "overall_score": 62.5,
  "score_payload": {
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
}
```

Do not hide scoring logic behind a single opaque number.

## Output

A scored assessment produces:

1. **Per-domain scores** — each domain 0–100 or null (unknown)
2. **Overall score** — weighted composite across scored domains only
3. **Rationale** — human-readable explanation of why scores are what they are
4. **Risk profile** — red/yellow/green/grey per domain (grey = unknown)

## Design Principles

- The score is a **communication device**, not a precise measurement
- Weights should be explicit and adjustable, not hardcoded
- Score effects are additive deltas, not absolute values
- The rule engine should not attempt sophisticated score normalization in v1
- Absence of findings does not imply health — probes may have been skipped

## Supabase-Specific Scoring Adjustments

### RLS Performance Tax

For Supabase assessments, the performance domain baseline should account for RLS overhead. RLS adds 5-50ms per query depending on policy complexity. When scoring performance for Supabase workloads, consider that some latency is structural and not a defect. However, missing indexes on RLS columns amplify this overhead dramatically and should score severely.

### Tier-Aware Thresholds

Supabase instance tiers determine available resources. Scoring thresholds should adjust:

- **Small tier:** max_connections is low (~60); utilization > 70% is already medium severity. Shared memory is limited; cache efficiency is more critical.
- **Medium tier:** moderate headroom; standard thresholds apply.
- **Large/XL:** more resources but higher cost; cost domain becomes more impactful per finding.

### System Schema Health Domain

Consider adding a sub-domain or tagging system for findings that relate to Supabase system schemas (auth, storage, realtime). These tables are not under customer control but affect customer experience. Findings in system schemas should be flagged with a "platform" tag to distinguish from user-schema issues. This helps prioritize: user-schema issues are customer-actionable; system-schema issues may require Supabase support engagement.

### Managed Service Profile

Add a `supabase_default` profile with adjusted weights:

| Domain              | Weight | Rationale                                                    |
|---------------------|--------|--------------------------------------------------------------|
| Performance         | 25%    | Most customer-visible; includes RLS tax                      |
| Availability        | 20%    | Platform manages HA but slot lag and WAL bloat are risks     |
| Storage             | 20%    | Direct billing impact; system schema bloat adds to cost      |
| Concurrency         | 15%    | Pool mode and connection limits are tier-constrained         |
| Operational Hygiene | 10%    | Includes system schema maintenance and extension health      |
| Efficiency          | 5%     | Less tunable in managed context                              |
| Cost                | 5%     | Tier-based pricing means less micro-optimization opportunity |
