# Grok This Repository

Critically analyze this repository's documentation, auto-fix what can be fixed, and log anything unresolvable to a residuals file. Each pass uses a fresh subagent with zero prior context.

## Usage

`/grok [N] [cutoff]` — run up to N passes (default: 1), stopping early if new items found drops to cutoff or below (default: 0). Use cutoff -1 to force all N passes.

## What To Do

Parse arguments from: $ARGUMENTS

- First argument: iteration count N (default: 1, must be a positive integer)
- Second argument: early stopping cutoff (default: 0, must be an integer >= -1)

Examples:
- `/grok` → 1 pass, cutoff 0
- `/grok 5` → up to 5 passes, stop when new items = 0
- `/grok 10 2` → up to 10 passes, stop when new items <= 2
- `/grok 10 -1` → force all 10 passes regardless

### Run the passes

Maintain an array of "new items found" counts, one per pass.

For each iteration (1 through N):

1. Announce: `### Grok pass [X] of [N]`
2. Launch a single `general-purpose` Agent with the subagent prompt below. Do NOT read the docs or the residuals file yourself — the subagent does everything in isolation.
3. Wait for it to complete fully (the subagent finishes, commits, and returns its report).
4. Parse the `NEW_ITEMS=[N]` line from the first line of the subagent's response. Record that number for this pass.
5. Briefly announce: `Pass [X]: [N] new items found`
6. **Early stopping check**: If the new items count for this pass is <= cutoff AND cutoff >= 0, this is the last pass. Announce: `Stopping early — new items ([N]) <= cutoff ([cutoff])` and proceed to Present Results.
7. Only then proceed to the next iteration.

### Present Results

Let P = the actual number of passes completed (which may be less than N due to early stopping).

**If P = 1 (single pass):** Present the subagent's summary directly. Remind the user to check `docs/RESIDUALS.md` if new residuals were added.

**If P >= 2 (multiple passes):** Read `docs/grok-log.md` and produce a distilled summary plus a convergence graph.

The convergence graph is an ASCII bar chart showing new items found per pass:

```
New items found per pass (target: 0)

  Pass 1 │████████████████████████████ 7
  Pass 2 │████████████████ 4
  Pass 3 │████████████ 3
  Pass 4 │████ 1
  Pass 5 │████ 1
         └─────────────────────────────
```

Scale bars proportionally to the maximum value. Use `█` characters. At least 1 `█` wide if count > 0. A count of 0 shows no bar, just the number:

```
  Pass 6 │ 0
```

If early stopping triggered, annotate the last pass:

```
  Pass 6 │████ 1  ← stopped (cutoff: 2)
```

If the trend is decreasing, add: `Trend: converging 👍`
If the trend is flat or increasing, add: `Trend: not yet converging — consider reviewing docs/RESIDUALS.md`
If early stopping triggered, also add: `Early stop after [P] of [N] passes`

Full output structure for multi-pass:

```
## Grok Complete — [P] of [N] passes

### Convergence

[the ASCII bar chart]

[trend note]

### Aggregate counts
- **Total issues found across all passes**: [sum]
- **Total auto-fixed across all passes**: [sum]
- **Total new residuals added across all passes**: [sum]

### Themes
[2-5 bullet points identifying patterns across passes]

### What's left
[Brief description of what remains in docs/RESIDUALS.md that needs human attention, if anything new was added]

### Raw log
Full per-pass details are in `docs/grok-log.md`.
```

## Important

- Strictly sequential. Never start pass X+1 until pass X has fully completed and committed.
- Each pass spawns its own fresh subagent — no context carries between passes.
- If a pass fails (subagent errors out), record its new-items count as `?`, log the failure, and continue to the next pass. Don't abort the loop.
- Do NOT push to remote. The user will push when ready.
- For multi-pass runs, the per-pass raw summaries live in `docs/grok-log.md`. Don't repeat them verbatim — distill them.

## Subagent Prompt

Launch this as a general-purpose Agent for each pass:

```
You are a critical reviewer and autonomous editor for a repository's documentation. You have no prior context about this project — read everything fresh and form your own conclusions. You will find problems, fix what you can, and log what you can't.

PROJECT ROOT: /Users/davida.ventimiglia/Work/pg-healthkit
RESIDUALS FILE: /Users/davida.ventimiglia/Work/pg-healthkit/docs/RESIDUALS.md
LOG FILE: /Users/davida.ventimiglia/Work/pg-healthkit/docs/grok-log.md

## Phase 1: Read All Documentation (no memory, no residuals)

DO NOT read the residuals file yet. Read every markdown document and contract file systematically. Use parallel reads where possible for speed.

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

## Phase 2: Find All Problems

Synthesize what you've read, then systematically identify every issue. For each, cite specific documents and sections.

Categories to check:

**Ambiguities** — meaning unclear or could be interpreted multiple ways:
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

**Structural Issues** — problems with documentation organization:
- Circular references between docs
- Information duplicated in multiple places (drift risk)
- Important details buried in the wrong document
- Missing cross-references where they'd help

Compile a complete list of every issue found. Be specific — cite file paths and section names.

## Phase 3: Deduplicate Against Residuals

NOW read the residuals file (docs/RESIDUALS.md). If it doesn't exist, skip this step — all findings are new.

Compare each finding from Phase 2 against the residuals. A finding is a duplicate if it describes the same underlying problem, even if worded differently. Mark each finding as either:
- **KNOWN** — already in residuals (skip it, don't try to fix it, it needs human input)
- **NEW** — not in residuals (proceed to Phase 4 with it)

## Phase 4: Auto-Fix New Issues

For each NEW finding, attempt to resolve it by editing the relevant documentation files directly. Follow these principles:

- Contracts (YAML files) are the source of truth. When prose disagrees with contracts, fix the prose.
- When two docs contradict each other, determine which is more authoritative based on the document hierarchy (methodology > data model > catalogs > implementation details) and fix the less authoritative one.
- For inconsistent terminology, pick the term used in the contracts or the methodology doc and update the others.
- For gaps where the answer is clearly implied by surrounding context, fill it in.
- For vague thresholds where a specific number exists elsewhere in the docs, use that number.

**DO NOT attempt to fix issues that require human judgment**, such as:
- Design decisions where multiple valid approaches exist
- Missing domain knowledge that isn't implied anywhere in the docs
- Thresholds or values that need business/operational input
- Architectural choices where the tradeoffs aren't clear from the docs alone
- Anything where you'd be guessing rather than deducing

When you fix something, make the minimal edit needed. Don't rewrite sections or restructure documents.

## Phase 5: Update Residuals

For any NEW findings that you could NOT fix (they require human input), append them to docs/RESIDUALS.md.

If the file doesn't exist, create it with this header:

```markdown
# Residuals

Issues identified by `/grok` that require human judgment to resolve. Items are never automatically removed — manage this file manually.

---
```

For each new residual, append an entry in this format:

```markdown
## [Category]: [Brief title]

- **Found in**: [file path(s) and section(s)]
- **Problem**: [specific description of the issue]
- **Why it needs human input**: [why the agent couldn't resolve this autonomously]
- **Detected**: [today's date]
```

IMPORTANT: Never remove or modify existing entries in the residuals file. Only append new ones.

## Phase 6: Commit Changes

After all edits are complete, create a single git commit with a conventional commit message summarizing what was fixed. Use a message like:

  fix: resolve N doc issues found by /grok (M new residuals logged)

Do NOT push. Just commit.

## Phase 7: Write Summary to Log

Append a timestamped summary to the log file (docs/grok-log.md). If the file doesn't exist, create it with a `# Grok Log` header first.

Append an entry in this format:

```markdown
---

### [today's date and time]

**Counts:**
- Total issues found: [N]
- Already known from residuals: [N]
- New issues found: [N]
- New issues auto-fixed: [N]
- New residuals added: [N]

**Fixes made:**
- [brief description of each fix]

**New residuals added:**
- [brief description of each new residual, or "None"]
```

Include the log file in the git commit from Phase 6.

## Phase 8: Report

Return the same summary content that was written to the log. IMPORTANT: The very first line of your response MUST be exactly this format so the caller can parse it:

```
NEW_ITEMS=[N]
```

Where [N] is the "New issues found" count from the summary. Follow it with the rest of the summary content.

## Guidelines

- Be specific in citations. "The scoring model is unclear" is useless. "In docs/10_scoring_model.md section 'Domain Weights', the formula references domain_weight but docs/02_assessment_model.md section 'Score Computation' calls this weight_factor" is actionable.
- Be honest but constructive.
- Distinguish between "this is wrong" and "this is a design choice I'd question."
- Cross-reference aggressively — the most valuable findings are where documents disagree with each other or with the contracts.
- When in doubt about whether you can fix something, err on the side of logging it as a residual. Don't guess.
```
