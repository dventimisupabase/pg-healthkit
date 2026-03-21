# Rules Evaluation Semantics

This document explains how `rules.yaml` should be interpreted by humans and by any implementation generated from it.

## Purpose

The rules layer converts normalized probe evidence into:

- findings
- severity
- confidence
- score adjustments

The rule engine is intentionally declarative. SQL probes collect evidence. The rules engine interprets that evidence. Reporting then renders the resulting findings and scores.

## Execution Model

At a high level, evaluation proceeds in this order:

1. Load assessment context
2. Load normalized probe payloads
3. Iterate through enabled rules for the active profile
4. Verify required probes are present
5. Evaluate rule cases in order
6. When a case matches, create the finding and apply score deltas
7. Continue to the next rule

A rule is independent from other rules unless an implementation explicitly adds cross-rule logic later.

## Profiles

Each rule declares the profiles in which it is active, for example:

- `default`
- `performance`
- `reliability`
- `cost_capacity`

A rule should only be evaluated if:

- the rule is `enabled: true`, and
- the current assessment profile is included in the rule’s `profiles` list

If the assessment profile is not listed, the rule should be skipped.

## Required Probes

Each rule declares `evidence.required_probes`.

If any required probe is missing, the rule should be skipped rather than failed.

That distinction matters:

- **skipped** means the system lacked required evidence
- **failed** should be reserved for evaluator or system errors

This preserves diagnostic integrity and avoids falsely implying that “no finding” means “healthy.”

## Fact Resolution

Each condition references a fact using:

- `from`: the probe name or `assessment_context`
- `fact`: a dot-path into the normalized payload

Examples:

- `from: long_running_transactions`
- `fact: summary.oldest_xact_age_seconds`

- `from: database_activity`
- `fact: stats.deadlocks`

- `from: assessment_context`
- `fact: assessment.workload_type`

Dot-path resolution rules:

1. Start at the normalized object for the named source
2. Split the fact path on `.`
3. Traverse keys in order
4. If any key is missing, resolution returns “missing”

Missing facts do not raise a hard error during case evaluation. Instead, that condition evaluates false.

## Operators

The supported operators are intentionally small:

- `gt`, `gte`, `lt`, `lte`
- `eq`, `neq`
- `contains`, `not_contains`
- `in`, `not_in`
- `exists`, `not_exists`
- `regex`

Guidance:

- numeric operators should only be used on normalized numeric fields
- `eq` and `neq` should support string, numeric, boolean, and null-safe comparison
- `contains` is intended for strings or arrays
- `exists` checks that a fact path resolves to a present value
- `not_exists` checks that the fact path does not resolve

## Combinators

A case condition can use:

- `all`
- `any`

`all` means every child condition must evaluate true.

`any` means at least one child condition must evaluate true.

Nested combinators are allowed in principle, but v1 should keep usage shallow and simple.

## Evaluation Modes

The current rules file primarily uses `mode: first_match`.

This means:

- evaluate cases in order
- the first case whose condition evaluates true wins
- later cases in the same rule are ignored

This is useful when cases represent ordered severity bands.

An implementation may support additional modes later, but v1 should treat `first_match` as the primary behavior.

## Severity and Confidence

When a case matches, the engine emits:

- severity
- confidence

Severity should be one of:

- `info`
- `low`
- `medium`
- `high`
- `critical`

Confidence should be one of:

- `low`
- `medium`
- `high`

Interpretation:

- **severity** describes operational or business importance
- **confidence** describes how trustworthy the inference is from the available evidence

A finding can be high severity with medium confidence, or low severity with high confidence. These are distinct dimensions.

## Finding Construction

Each rule defines a `finding` block with:

- `key`
- `domain`
- `title`
- `summary_template`
- `impact_template`
- `recommendation_template`
- `tags`

When a case matches, the engine should construct a finding object by:

1. copying the static finding metadata
2. rendering templates using the matched context
3. attaching references to the probe evidence used
4. recording matched case metadata if helpful for debugging

The `finding.key` should be stable over time. It is the canonical identifier for the issue class.

## Template Interpolation

Templates use `${...}` interpolation.

Examples:

- `${summary.row_count}`
- `${summary.oldest_xact_age_seconds}`
- `${stats.deadlocks}`

The interpolation context should be formed from the source objects used by the matched case. A practical v1 approach is:

- expose the primary probe payload at top-level names such as `summary`, `stats`, `bgwriter`
- also expose `assessment`
- optionally expose rule metadata such as thresholds

If a template variable is missing, the safest v1 behavior is either:

- leave it blank, or
- render a placeholder such as `<missing>`

Do not crash report generation because of a missing interpolation value.

## Score Effects

Each matching case may specify `score_effects`, for example:

```yaml
score_effects:
  concurrency: -20
  storage: -10
  availability: -8
```

These are additive deltas applied to the current domain scores.

Recommended v1 scoring behavior:

- initialize each score domain to 100
- apply all matched rule deltas
- clamp each final domain score to the range 0–100
- compute overall score from weighted domain scores outside the rule engine

The rule engine should not attempt sophisticated score normalization in v1.

## Skip vs No-Match vs Error

These states should be distinct.

### Skip
Use when:
- the rule is disabled
- the profile does not apply
- a required probe is missing

### No match
Use when:
- the rule was evaluated
- required evidence existed
- no case condition matched

### Error
Use when:
- evaluator logic fails
- payload is malformed beyond recovery
- an internal rule-processing bug occurs

This distinction is important for both operator trust and debugging.

## Normalization Contract Dependency

The rule engine assumes that probes have already been normalized into stable payload shapes.

That means the SQL runner, parser, or evidence ingester must map raw tabular output into canonical objects with predictable fields such as:

- `summary.oldest_xact_age_seconds`
- `summary.utilization_pct`
- `stats.deadlocks`
- `summary.max_temp_blks_written`

The probe registry defines these contracts.

If normalization changes, rules may break. That is why `probe_registry.yaml` is a companion artifact, not optional documentation.

## Recommended Evaluator Structure

A minimal implementation should separate concerns into:

- probe loader
- normalized evidence store
- rule evaluator
- finding renderer
- score accumulator

Pseudo-flow:

1. load assessment
2. load evidence by probe name
3. choose profile
4. for each rule:
   - check profile
   - check required probes
   - evaluate cases
   - if matched:
     - render finding
     - add score deltas
5. emit findings and scores

## Non-Goals for v1

The rules layer should not attempt to do the following yet:

- trend analysis across time windows
- cross-assessment benchmarking
- statistical anomaly detection
- automatic remediation execution
- complicated dependency graphs between rules

Those can be added later once the evidence and evaluation model are stable.

## Design Principles

The most important principles are:

- keep rules explicit
- keep findings explainable
- keep evidence inspectable
- keep scoring transparent
- prefer stable contracts over clever abstractions

That is the basis for generating executable logic reliably from `rules.yaml`.
