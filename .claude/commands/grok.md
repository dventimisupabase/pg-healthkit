# Grok This Repository

Spawn a subagent to critically analyze this repository's documentation with fresh eyes. The subagent starts with zero prior context every time — no accumulated bias from previous runs or conversations.

## What To Do

Use the Agent tool to launch a single `general-purpose` subagent with the following prompt. Pass it verbatim (adjusting the project path if needed). Do NOT read the docs yourself first — the whole point is that the subagent does the analysis in isolation.

After the subagent returns, present its findings to the user and ask which issues they want to address. You (in the main conversation) handle the fixes, and the user can run `/grok` again for a fresh review.

## Subagent Prompt

Launch this as a general-purpose Agent:

```
You are a critical reviewer performing a deep, independent analysis of a repository's documentation and plans. You have no prior context about this project — read everything fresh and form your own conclusions.

PROJECT ROOT: /Users/davida.ventimiglia/Work/pg-healthkit

## Step 1: Read All Documentation

Read every markdown document and contract file systematically. Use parallel reads where possible for speed.

Batch 1 (read in parallel):
- docs/README.md
- docs/01_methodology.md
- docs/02_assessment_model.md
- docs/03_human_checklist.md
- docs/04_data_model.md
- docs/05_context_ingestion.md
- docs/06_assessment_orchestration.md
- docs/07_probe_system.md
- docs/08_cli_contract.md

Batch 2 (read in parallel):
- docs/09_rule_engine.md
- docs/10_scoring_model.md
- docs/11_probe_catalog.md
- docs/12_findings_catalog.md
- docs/13_roadmap.md
- docs/14_cross_assessment_model.md
- docs/15_normalizer.md
- docs/16_report_template.md

Batch 3 (read in parallel):
- docs/IMPLEMENTATION_PLAN.md
- docs/sample_report_template.md
- contracts/probe_registry.yaml
- contracts/rules.yaml
- CLAUDE.md
- README.md
- CONTRIBUTING.md
- cli/CLAUDE.md
- arena/CLAUDE.md
- probes/README.md

Then scan the probes/ directory for SQL files and spot-check a few against what the docs claim.

## Step 2: Build a Mental Model

Before critiquing, synthesize what you've read. Understand:
- The core thesis and value proposition
- The architectural decisions and their rationale
- The data flow end-to-end (context -> probes -> normalization -> rules -> scores -> findings -> reports)
- The separation of concerns (CLI vs Arena vs Contracts)
- The personas, objectives, workload types, and health domains
- The phased delivery plan

## Step 3: Critical Scrutiny

Systematically look for these categories of issues. For each issue, cite specific documents and sections.

**Ambiguities** — meaning is unclear or could be interpreted multiple ways:
- Undefined or under-defined terms
- Vague thresholds or criteria ("significant", "large", "many")
- Unclear ownership of responsibilities between components
- Hand-wavy descriptions of mechanisms that need to be precise

**Inconsistencies** — two documents disagree or use conflicting terminology:
- Same concept called different names in different docs
- Conflicting definitions of enums, statuses, or categories
- Schema fields in the data model that don't match the contracts
- Probe names/IDs that differ between the catalog, registry, and SQL files
- Rule definitions that reference findings or probes that don't exist (or vice versa)

**Contradictions** — documents make mutually exclusive claims:
- One doc says X belongs in CLI, another says it belongs in Arena
- Scoring formulas that produce different results depending on which doc you follow
- Lifecycle states or transitions that conflict

**Gaps** — important things missing or incomplete:
- Probes referenced but not defined
- Rules that reference evidence no probe collects
- Findings with no corresponding rule to trigger them
- Missing error handling or edge case documentation
- Undocumented API endpoints or data flows
- Persona objectives with no probes mapped to them

**Structural Issues** — problems with how the documentation is organized:
- Circular references between docs
- Information duplicated in multiple places (drift risk)
- Important details buried in the wrong document
- Missing cross-references where they'd help

## Step 4: Present Findings

Organize findings into a clear, prioritized report using this structure:

## Critical Issues (would block implementation or cause bugs)
1. [Issue title] — [brief description]
   - **Where**: [doc A, section X] vs [doc B, section Y]
   - **Problem**: [specific description]
   - **Suggested resolution**: [concrete suggestion]

## Significant Issues (would cause confusion or rework)
...same format...

## Minor Issues (cleanup and polish)
...same format...

## Observations (not issues, but worth noting)
- Things that are well-done and should be preserved
- Patterns that could be extended
- Questions that only the author can answer

## Guidelines

- Be specific. "The scoring model is unclear" is useless. "In docs/10_scoring_model.md line 45, the formula references domain_weight but docs/02_assessment_model.md calls this weight_factor" is actionable.
- Be honest but constructive. The goal is improvement, not criticism.
- Distinguish between "this is wrong" and "this is a design choice I'd question." Flag both, but label them differently.
- Cross-reference aggressively. The most valuable findings are where documents disagree with each other or with the actual code/contracts.
- Check the contracts (YAML files) against the prose docs — contracts are the source of truth per CLAUDE.md, so when they disagree, the prose should change.
- Don't just find problems — suggest solutions. Every issue should have a "suggested resolution."
- Return the FULL report — do not truncate or summarize. The user needs every finding.
```
