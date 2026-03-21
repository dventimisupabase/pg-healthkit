# Normalizer

## Purpose

The normalizer transforms raw SQL tabular output into canonical probe payloads. It is the boundary between evidence collection (probes) and evidence interpretation (rules).

Without stable normalization, the rule engine cannot reliably resolve facts, the scoring model cannot compute domain scores, and reports cannot render findings consistently.

## Position in the Pipeline

```
SQL Probe → Raw Tabular Result → Normalizer → Canonical Payload → Rule Engine
```

The normalizer sits between the SQL runner and everything downstream. It is the contract enforcement point.

## Responsibilities

The normalizer is responsible for:

- Parsing raw query results (array rows or object rows)
- Coercing values into canonical types (numeric, boolean, null, ISO-8601)
- Constructing probe-specific `summary` objects for rule evaluation
- Truncating or sanitizing large text fields (query text at 1000 characters)
- Emitting a predictable payload even when row counts are zero
- Distinguishing `success`, `skipped`, and `failed` execution outcomes

The normalizer is **not** responsible for:

- Evaluating rules
- Assigning severity
- Computing scores
- Generating reports

## Canonical Envelope

Every normalized probe payload uses this envelope structure:

```json
{
  "probe_name": "<name>",
  "probe_version": "<version>",
  "status": "success | skipped | failed",
  "summary": { ... },
  "rows": [ ... ],
  "metadata": {
    "duration_ms": 14,
    "database_name": "postgres",
    "collector_version": "0.1.0",
    "normalizer_version": "0.1.0",
    "contract_version": "v1",
    "warnings": []
  }
}
```

Skipped probes use `"status": "skipped"` with a `skip_reason` field. Failed probes use `"status": "failed"` with an `error` object. Both still emit `summary` and `rows` (empty).

## Type Coercion Rules

| Source Type        | Target                                             | Rule                                              |
|--------------------|----------------------------------------------------|----------------------------------------------------|
| NULLs              | JSON `null`                                        | Never substitute empty strings or `"N/A"`         |
| Numeric strings    | Integer or number                                  | `"500"` → `500`                                   |
| PostgreSQL intervals | Seconds or milliseconds                          | Use `_seconds` or `_ms` suffix per registry       |
| Size values        | Bytes (integer)                                    | Never use human-readable strings like `"12 GB"`   |
| Booleans           | `true` / `false`                                   | Normalize from PostgreSQL `t`/`f` if needed       |
| Timestamps         | ISO-8601 strings                                   | `"2026-03-20T20:15:00Z"`                          |
| Query text         | Truncated string                                   | 1000 character maximum                            |

## Summary Object

Every probe exposes a `summary` object with stable scalar fields for rule evaluation. The normalizer computes summary fields deterministically from normalized rows, not from raw untyped results.

Examples:

- `summary.row_count` — number of rows returned
- `summary.oldest_xact_age_seconds` — from `long_running_transactions`
- `summary.max_dead_tuple_pct` — from `dead_tuple_ratio`
- `summary.utilization_pct` — from `connection_pressure`
- `summary.zero_scan_large_index_count` — from `unused_indexes`

These are the fields that `rules.yaml` resolves via dot-path (e.g., `fact: summary.oldest_xact_age_seconds`).

## Zero-Row Handling

If a probe executes successfully but returns no rows:

- `status` remains `"success"`
- `rows` is `[]`
- `summary.row_count` is `0`
- Max/min fields are `0` or `null` per the registry contract

This is important: zero rows is a valid observation, not a failure.

## Determinism

Given the same raw result, the normalizer must produce the same canonical payload. This matters for reproducible findings, testability, and diffing between assessment runs.

## Interface Boundary

The normalizer defines a clean boundary between two components:

**SQL Runner** — executes probes, captures raw output, represents skip/fail states. Makes no rule-level decisions.

**Normalizer** — converts raw rows to named objects, coerces types, derives summaries, validates against registry. Makes no severity or scoring decisions.

The suggested Go interface:

```go
type Normalizer interface {
    Normalize(raw RawProbeResult) (CanonicalProbePayload, error)
}
```

A registry-aware variant:

```go
type RegistryAwareNormalizer interface {
    NormalizeWithContract(probeName string, raw RawProbeResult, contract ProbeContract) (CanonicalProbePayload, error)
}
```

## Validation

After normalization, validate the payload against `probe_registry.yaml`. Validation failures should produce `status: failed` or a rejected upload. For v1, surface errors clearly with probe name, missing field, and expected type.

## Forward Compatibility

The normalizer may add fields beyond the registry contract, but must not remove existing fields, change field meaning or units, or rename fields silently. If a contract changes, bump the version in the registry and adjust rules accordingly.

## Detailed Specifications

This document provides the conceptual model. For complete specifications:

- `contracts/normalizer_spec.md` — full transformation rules, probe-specific summary derivation, and determinism requirements
- `contracts/normalizer_interface_contract.md` — raw input/output shapes, error handling, metadata contract, Go interface signatures, and end-to-end transformation examples
