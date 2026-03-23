# Trial Protocol

> **Status: GOLD** — 7 trials completed (2026-03-21 to 2026-03-22). Design docs reached stability at trial 03 (zero doc-fix commits in trials 03-07). Trial 07 validated canonical payload fixture tests as the solution to cross-trial finding-count variation. The trial protocol has served its purpose — docs are solid.

## Purpose

Each trial is a stress test of the design docs. The implementation is the test; the design docs are the code under test. Trials reveal ambiguities, gaps, and incorrect assumptions in the docs. The docs get tighter with each trial. The code is forensic evidence, not a deliverable.

## What Lives on Main

- Design docs (`docs/`)
- Contracts (`contracts/`)
- SQL probes (`probes/`)
- Lessons learned (`docs/lessons_learned.md`)
- This protocol (`docs/trial_protocol.md`)
- No implementation code

## What Lives on Trial Branches

- Implementation code (`cli/`, `arena/`)
- Doc-fix commits (cherry-picked back to main)
- Everything else from main

Trial branches are retained for forensic comparison across trials but are not merged to main.

## Before Each Trial

1. Ensure main is up to date (all previous trial doc fixes cherry-picked)
2. Create branch: `git checkout -b trial_NN main`
3. Agent reads in this order:
   - `docs/lessons_learned.md` (mistakes to avoid)
   - `docs/trial_protocol.md` (this file)
   - `docs/01_methodology.md` (conceptual framework)
   - `contracts/probe_registry.yaml` and `contracts/rules.yaml` (source of truth)
   - `docs/15_normalizer.md`, `docs/04_data_model.md`, `docs/09_rule_engine.md` (specs)
   - `docs/IMPLEMENTATION_PLAN.md` (build order)
   - `CLAUDE.md` and `cli/CLAUDE.md` and `arena/CLAUDE.md` (project rules)
4. No planning ceremony. No spec documents. No code in plans. Implement from the docs.

## During Each Trial

### Commit discipline

Every commit is either a **doc commit** or an **implementation commit**. Never mix them.

- **Doc commits** (cherry-picked to main after the trial):
  - Prefix: `docs:`
  - Fix ambiguities, add missing details, correct errors in design docs
  - Update `lessons_learned.md` with new findings
  - These are the valuable output of the trial

- **Implementation commits** (stay on the trial branch):
  - Prefix: `feat:`, `fix:`, `chore:`, `test:`
  - The actual code — disposable but retained for forensic study

### When the agent hits ambiguity

This is the most important moment in a trial. When a design doc is unclear:

1. Stop implementing
2. Fix the doc in a `docs:` commit (describe what was ambiguous and how it was resolved)
3. Continue implementing from the fixed doc

Do not work around ambiguity in code. Fix the doc. That's the whole point.

### Testing approach

- TDD for the first vertical slice (3 probes) to lock down types and interfaces
- Boundary-level integration tests for broadening:
  - CLI test suite: all probes against a real database, validate summaries
  - Arena test suite: evidence fixtures → run_analysis → assert findings and scores
- End-to-end validation against a real Supabase project

### Tools

- Go for the CLI (pgx, yaml.v3, stdlib)
- Supabase CLI for migrations and seeds (`supabase db push`, `supabase db reset`)
- `psql` for ad-hoc SQL and debugging
- Supabase MCP only for project provisioning
- Go code generators for contract → SQL/code translation

## After Each Trial

### 1. Structured retrospective

Answer these questions (use the form tool for interactive sessions):

**Planning:** Was the implementation plan sufficient? Were there steps missing or in the wrong order?

**Doc quality:** Where did the agent hit ambiguity? Were all doc fixes captured as `docs:` commits?

**Testing:** Was the testing approach adequate? What would have caught bugs earlier?

**Tooling:** Were the right tools used? Any friction from tool choices?

**Timing:** How did effort distribute across phases? Was any phase disproportionate?

### 2. Update lessons learned

Add a trial history entry to `docs/lessons_learned.md`:

```markdown
### Trial NN — YYYY-MM-DD

**Scope:** What was attempted (which phases, which probes, etc.)

**Doc fixes:** List of doc commits and what they fixed

**New lessons:** What was learned that wasn't known before

**Status:** Complete / Partial (and why)
```

### 3. Cherry-pick doc fixes to main

```bash
git checkout main
# Cherry-pick all docs: commits from the trial
git cherry-pick <hash1> <hash2> ...
git push origin main
```

### 4. Retain the trial branch

```bash
# Push the trial branch for forensic retention
git push origin trial_NN
# Do NOT delete — retained for cross-trial comparison
```

## Done Criteria

The design docs are "solid" when a trial meets all of these:

- Agent implements the full plan without hitting any doc ambiguity
- The retrospective produces no new lessons
- All 28 rules fire correctly against synthetic evidence
- End-to-end test passes against a real Supabase project
- No doc-fix commits were needed during the trial

At that point, the implementation from the final trial can be promoted to main if desired — but even then, the docs are the primary artifact, not the code.

## Cross-Trial Comparison

Trial branches are retained so you can compare:

- How implementation approaches differed across trials
- Whether the same ambiguities recurred (indicating a doc fix didn't stick)
- How implementation time changed as docs improved
- Whether different agents (or the same agent in different sessions) produce consistent results from the same docs

```bash
# Compare two trials
git diff trial_01..trial_02 -- cli/
git diff trial_01..trial_02 -- arena/
git diff trial_01..trial_02 -- docs/
```
