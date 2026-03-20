# Rule Engine

## Role
Convert evidence → findings.

## Structure
Rule:
- inputs (probes)
- condition (threshold/heuristic)
- output (finding)

## Example
long_running_transactions:
- input: long_running_transactions probe
- condition: xact_age > 1h
- output: high severity finding

## Principles
- Keep rules explainable
- Include confidence levels
- Avoid overfitting thresholds
