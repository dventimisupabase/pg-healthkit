# Methodology Overview

## Core Principle

Health = f(persona, objective, workload, evidence, interpretation)

Health is not an absolute property of a database. It is relative to the intended use, the people responsible for it, and the business context in which it operates.

## Product Mindset

Treat this as a product, not a one-off health check. The right outcome is a small assessment framework with three artifacts:

1. **A standardized checklist** for humans (see `03_human_checklist.md`)
2. **A SQL probe pack** for evidence collection (see `07_probe_system.md` and `probes/`)
3. **A lightweight audit tool** that runs probes, scores findings, and produces reports (see `08_cli_contract.md`)

That gives you consistency, explainability, and room to mature over time. Every design decision should serve repeatability and credibility across engagements, not just one-time diagnostic convenience.

## Data Flow

```
Context (persona / objective / workload)
      ↓
Evidence (probes + platform data + customer input)
      ↓
Interpretation (rules + cross-signal synthesis)
      ↓
Scores + Findings
      ↓
Report (persona-aware)
```

Probes are only one input channel. Context defines the meaning of evidence. Interpretation is multi-layered: rules produce findings, but prioritization, framing, and narrative require higher-order synthesis.

## 1. Anchor on Evaluation Intent

Every engagement must start by classifying into one or more of these intents:

| Intent                       | Driver                 | What "Healthy" Means                                             |
|------------------------------|------------------------|------------------------------------------------------------------|
| Reliability assurance        | DBA / SRE              | Low incident risk, failover readiness, vacuum/replication health |
| Performance optimization     | App developer          | Low query latency, predictable throughput, no contention         |
| Cost / capacity optimization | CTO / finance          | Right-sized resources, minimal waste, forecastable spend         |
| Pre-scale validation         | Engineering leadership | Ready to absorb growth without degradation                       |
| Post-incident forensics      | Ops / SRE              | Root cause identified, recurrence prevented                      |

Without explicit intent, metrics are meaningless. Each intent determines the lens.

## 2. Persona → Objective Mapping

Codify this as a matrix, not informal reasoning:

| Persona              | Primary Objective            | Secondary Objective    | Risk Sensitivity                 |
|----------------------|------------------------------|------------------------|----------------------------------|
| DBA / SRE            | Availability, stability      | Operability (low toil) | Very low tolerance for incidents |
| App Developer        | Query latency, correctness   | Predictability         | Moderate                         |
| CTO / Eng Leadership | Cost efficiency, scalability | Forecastability        | High for waste                   |

Every metric collected should map to at least one persona objective. This matrix is the lens selector.

## 3. Workload Classification

In practice, you need slightly more granularity than the classic OLTP/OLAP split:

| Workload Type        | Characteristics                                | Key Concerns                                                         |
|----------------------|------------------------------------------------|----------------------------------------------------------------------|
| OLTP                 | Latency-sensitive, high concurrency            | p95/p99 latency, lock contention, connection pressure                |
| OLAP                 | Scan-heavy, throughput-oriented                | Query throughput, temp spill, I/O patterns                           |
| Hybrid (HTAP)        | Mixed transactional and analytical             | Resource isolation, priority conflicts                               |
| Queue / Event-driven | Write-heavy, append-only                       | WAL pressure, checkpoint tuning, vacuum throughput                   |
| Vector / Embedding   | ANN search, high-dimensional, CPU/memory-heavy | Index type tuning (HNSW/IVFFlat), recall vs latency, memory pressure |
| Multi-tenant SaaS    | Shared resources, variable load                | Noisy neighbor risk, connection fairness, resource isolation         |

This classification defines expected baselines, not just observed metrics.

A 200ms query is catastrophic in OLTP, irrelevant in OLAP. An HNSW index build that takes 10 minutes is expected for vector workloads but would be alarming in OLTP.

## 4. Health Domains

Instead of jumping to metrics, define orthogonal domains of health. This prevents blind spots.

### A. Availability & Resilience
- Uptime, failover readiness, replication health
- Backup integrity (not just existence)
- RPO / RTO compliance

### B. Performance & Latency
- Query latency (p50 / p95 / p99)
- Throughput (TPS / QPS)
- Lock contention
- Buffer cache efficiency

### C. Resource Efficiency
- CPU saturation vs utilization
- Memory pressure (shared_buffers vs working set)
- I/O patterns (random vs sequential, IOPS vs throughput)

### D. Storage & Data Shape
- Table / index bloat
- Autovacuum effectiveness
- Dead tuple accumulation
- Index usage vs redundancy

### E. Concurrency & Contention
- Lock waits
- Connection saturation
- Transaction conflicts (especially in replicas)

### F. Operational Hygiene
- Vacuum / analyze cadence
- Long-running transactions
- Idle-in-transaction sessions
- Schema / index anti-patterns

### G. Cost & Capacity
- Growth rate (data + workload)
- Over / under-provisioning
- Storage vs compute balance
- Forecast horizon

## 5. KPI Layer

Attach specific metrics to each domain.

**Performance:**
- `pg_stat_statements`: mean_time, calls, stddev
- p95 latency (external APM if possible)
- Slow query percentage (> threshold)

**Concurrency:**
- `pg_locks` wait events
- `max_connections` vs active usage
- Connection queueing

**Storage:**
- Bloat ratio (table + index)
- Dead tuples / live tuples
- Autovacuum lag

**Efficiency:**
- Cache hit ratio (but contextualized — not a health score by itself)
- Temp file usage (spill indicator)
- Sequential vs index scan ratio

**Reliability:**
- Replication lag
- Backup success + restore test success
- WAL generation rate

## 6. Diagnostic Layer

This is where most "health checks" fail. Metrics alone are not enough — you need interpretation rules.

### Cross-Signal Heuristics

| Signal Combination              | Likely Cause                                                  |
|---------------------------------|---------------------------------------------------------------|
| High CPU + low I/O              | Inefficient queries or missing indexes                        |
| High I/O + low cache hit        | Working set exceeds memory                                    |
| High latency + low CPU          | Lock contention or I/O stalls                                 |
| Bloat + high write rate         | Autovacuum misconfiguration                                   |
| High temp writes + high latency | Sort/hash spill, likely work_mem or query design              |
| buffers_backend high            | Backends doing their own writes, checkpoint tuning may be off |

### Domain-Specific Diagnostic Heuristics

**Reliability:**
- Replication lag nontrivial or unstable → recovery risk, stale reads, failover concerns
- No evidence of restore testing → backup posture weak even if backups exist
- Long transactions → vacuum interference, bloat growth, xid age risk

**Performance:**
- Top total time query → best optimization leverage
- High mean latency with low calls → tail latency or inefficient reporting path
- High temp writes → sort/hash spill, likely work_mem or query design issue
- High shared block reads vs hits → memory pressure or poor locality

**Concurrency:**
- Blocking chains present → application transaction design or missing index patterns
- Many idle-in-transaction sessions → client behavior defect
- Active connections near max without pooling → saturation risk

**Storage and Maintenance:**
- High dead tuple ratio → autovacuum not keeping up or blocked
- Large indexes with zero scans → write amplification and storage waste
- High seq_scan on large OLTP tables → possible missing index or poor filter selectivity

**Efficiency and Sizing:**
- CPU low but latency high → likely contention or I/O
- I/O high with temp spill → sort/hash overflow
- buffers_backend high → backends doing their own writes, checkpoint tuning may be off

**Capacity:**
- High WAL volume plus write-heavy workload → storage and replica pressure
- Largest relations dominate total size → focus cost review there first
- max_connections set far above realistic need → memory fragmentation and operational risk

This becomes the heuristic engine. Rules should be explicit about what they infer and at what confidence.

## 7. Scoring Model

To make assessments customer-facing and repeatable, introduce scoring:

- Each domain scored 0–100
- Weighted by persona intent

Weights vary by assessment profile (e.g., DBA/SRE vs CTO). Other profiles (reliability, cost_capacity, performance, supabase_default) shift these weights significantly — for example, `cost_capacity` gives Cost 30% weight vs 10% here. The default profile weights are:

| Domain              | Weight |
|---------------------|--------|
| Availability        | 20%    |
| Performance         | 20%    |
| Concurrency         | 15%    |
| Storage             | 15%    |
| Operational Hygiene | 10%    |
| Efficiency          | 10%    |
| Cost                | 10%    |

See `10_scoring_model.md` for all profiles (reliability, cost_capacity, performance, supabase_default) and the full scoring specification.

**Output:**
- Health Score (composite)
- Risk Profile (red / yellow / green / grey per domain; grey = unknown)

Do not overfit numeric precision. The score is a communication device, not science.

See `10_scoring_model.md` for full scoring specification.

## 8. Output Structure

Every evaluation should produce:

1. **Executive Summary** — persona-specific framing
2. **Key Risks** — ranked by severity and confidence
3. **Root Causes** — not symptoms
4. **Recommended Actions** — prioritized by impact vs effort
5. **Capacity Forecast** — if applicable

See `sample_report_template.md` for the canonical report format.

## 9. End-to-End Example Flow

1. Identify persona(s) + intent
2. Classify workload
3. Collect metrics across domains
4. Normalize against workload expectations
5. Diagnose using heuristics
6. Score domains
7. Produce prioritized remediation plan

## 10. Design Principles

**What to preserve:**
- Start with personas (correct)
- Recognize workload type as critical
- Think top-down (objectives → metrics)

**Where to tighten:**
- Introduce formal domains (prevents gaps)
- Separate metrics from interpretation
- Add scoring + prioritization (customers need decisions, not data)

## Anti-Patterns to Avoid

- Vanity metrics without interpretation
- Hard thresholds divorced from workload context
- Pretending a single snapshot gives trend insight
- Using only database-internal evidence when app symptoms matter
- Generating remediation advice without confidence or tradeoffs
- Reporting symptoms without diagnosing root causes — every finding should answer *why*, not just *what*

A credible health methodology says: "Here is what we know, how we know it, how confident we are, and what to do next."

## Supabase Platform Considerations

When applying this methodology to Supabase-managed databases, several platform-specific factors modify the assessment:

### PostgREST and API-Generated Queries

Supabase exposes PostgreSQL via PostgREST, which auto-generates SQL from HTTP requests. This means:
- Query patterns are generated, not hand-written — optimization requires understanding the HTTP-to-SQL mapping
- Complex REST queries with embedding (e.g., `?select=*,related_table(*)`) generate joins that may not have been explicitly designed
- Planning time overhead can be significant for complex PostgREST queries with many joins or filters

### Row Level Security (RLS)

RLS is enabled by default in Supabase and adds overhead to every query:
- Every query through PostgREST passes through RLS policies
- Missing indexes on columns referenced in USING clauses cause sequential scans on every request
- Policy complexity directly impacts latency — policies with subqueries or function calls add compounding overhead
- RLS policy indexing should be treated as a first-order performance concern, not a secondary check

### Managed Service Constraints

Supabase customers have limited control over:
- Instance sizing (determined by tier)
- Default PostgreSQL configuration (shared_buffers, max_connections set by tier)
- Background maintenance scheduling
- Extension availability and versions

This means:
- Some remediation paths (e.g., "increase shared_buffers") are not directly available — the recommendation becomes "upgrade tier" or "optimize queries to fit within current resources"
- Configuration hygiene findings should distinguish between tunable and non-tunable settings
- Cost recommendations should reference tier upgrades rather than infrastructure tuning

### System Schemas

Supabase manages several schemas that are not customer-created but affect customer experience:
- `auth.*` — authentication tables (users, sessions, refresh_tokens, mfa_factors)
- `storage.*` — file storage metadata (objects, buckets)
- `realtime.*` — real-time subscription infrastructure
- `extensions.*` — extension management
- `supabase_functions.*` — edge function metadata

Health issues in these schemas (bloat, stale vacuum, excessive growth) are platform concerns but manifest as customer-visible symptoms (slow logins, delayed file access, subscription lag). The assessment should monitor these schemas and clearly tag findings as "platform" vs "user" origin.
