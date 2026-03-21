# Lessons Learned: v1 Implementation

Notes from the first full implementation of pg-healthkit, covering what worked, what didn't, and what to do differently next time.

## Context

The v1 system was built in a single session on the `trial_01` branch. It covers Phases 1-5 of the implementation plan: probe runner, normalization, rule evaluation, reporting, and persistence. The design docs (methodology, contracts, normalizer spec, data model, rule engine spec) were written before implementation began.

## What Worked

### Contracts as the source of truth

`probe_registry.yaml` and `rules.yaml` drove everything. The CLI reads them, the normalizer derives from them, the rule engine evaluates from them, the seed tool generates from them. When we needed all 28 rules in the Arena database, we wrote a Go program that read the YAML and produced SQL — zero transcription errors. Build tooling that reads contracts, never transcribe from them manually.

### Design docs were excellent

The methodology, contracts, normalizer spec (`docs/15_normalizer.md`), and data model (`docs/04_data_model.md`) were precise enough to code from directly. Most of the implementation was mechanical translation of specs into Go or SQL. The docs didn't need revision during implementation.

### Deeper-then-broader (vertical slice)

Building the full pipeline for 3 probes first (probe → normalize → evaluate → score → report), then broadening to 24 probes, avoided architectural rework. The types, interfaces, and data flow were proven before we scaled.

### Combining Phase 1+2

The normalizer was lightweight enough to build alongside the runner. Merging them avoided building a throwaway raw-output format and got us to canonical payloads immediately.

### Testing against real databases early

Running the CLI against local PostgreSQL and probes against Supabase databases caught real issues (relative path bugs, pgx type handling, RLS permissions) that unit tests alone wouldn't have found.

## What Didn't Work

### Heavyweight planning ceremony

The brainstorming/spec/plan skill chain (explore context → ask questions → propose approaches → present design → write spec → spec review → write plan → plan review) consumed roughly half the session. For a project with comprehensive design docs, this was disproportionate. The design docs already contained the spec — the ceremony mostly re-derived what was already written.

**Lesson:** For projects with thorough design docs, skip the spec and plan documents. Use a lightweight checklist in conversation tasks. The design docs are the spec.

### Plan written to wrong location

The plan was initially written to `docs/superpowers/specs/` and `docs/superpowers/plans/` (per the skill's convention), then had to be manually merged into `docs/IMPLEMENTATION_PLAN.md`. This was wasted effort.

**Lesson:** Write artifacts where they belong from the start. Follow the project's existing doc structure, not a plugin's conventions.

### Code in plans

The implementation plan contained full Go source code for every function. This created problems:
- The code had bugs (wrong paths, missing imports, type handling gaps) that required review cycles to find
- The actual implementation diverged from the plan in multiple places
- The code was a second source of truth that drifted from the real code immediately

Meanwhile, Phases 3-5 had no code in the plan and were implemented faster — because the design docs were sufficient.

**Lesson:** Don't put code in plans. If the spec is good, the AI generates correct code. Plans should describe *what* to build and *in what order*, not *how* to write each function.

### Supabase MCP for database operations

The Supabase MCP server was used for executing SQL against the Arena database. This introduced friction:
- Payload size limits required batching rule inserts into 4 separate MCP calls
- RLS had to be disabled manually because the anon key couldn't write
- No transaction support — each MCP call is independent
- Verbose compared to `psql` or `supabase db execute`

The MCP was useful for one thing: provisioning the new Supabase project. For everything else, the Supabase CLI and `psql` would have been simpler and more capable.

**Lesson:** Use the Supabase MCP for project provisioning. Use `supabase` CLI and `psql` for migrations, seeding, and SQL execution.

### Reinventing seed tooling

We built a custom Go tool to read `rules.yaml` and generate SQL INSERT statements, then manually batched them through the MCP. Supabase already supports seed files (`supabase/seed.sql`) as part of its migration framework. The Go tool was the right idea (deterministic generation from contracts), but the delivery mechanism should have been a Supabase seed file, not manual MCP calls.

**Lesson:** Use `supabase/seed.sql` for reference data. Generate it from contracts using a tool, then apply it with `supabase db reset` or during migration.

### TDD discipline degraded after Phase 1+2

Strict TDD (write test → fail → implement → pass) was followed for Phase 1+2 (8 tasks, 13 tests). But for Phases 3-5, no automated tests were written. The arena SQL functions, arena client, 21 new normalizer summaries, and report renderer were all validated only by end-to-end runs.

**Lesson:** Use TDD to nail down interfaces and types (Phase 1 vertical slice). Then use boundary-level test suites for bulk implementation:
- CLI test suite: run all 24 probes against a real database, validate all summaries have the fields that `rules.yaml` expects
- Arena test suite: insert evidence fixtures, run `run_analysis`, assert findings and scores match expected values
- Each side owns its boundary. Not per-function unit tests — per-layer integration tests.

## Recommendations for Future Implementation Sessions

### Before starting

1. Read the design docs (especially `01_methodology.md`, `15_normalizer.md`, `09_rule_engine.md`, `04_data_model.md`)
2. Read the contracts (`probe_registry.yaml`, `rules.yaml`)
3. Read this lessons doc
4. Do NOT write spec or plan documents — the design docs are the spec

### Implementation order

1. Scaffold Go module and packages
2. Implement registry loader (parse contracts)
3. Implement probe runner (pgx, SQL execution) for 3 probes
4. Implement normalizer (type coercion + summary derivation) for 3 probes
5. Implement validator (contract checking)
6. Wire up CLI entry point
7. Set up Arena: `supabase init`, apply schema migration, generate seed file from contracts, apply seed
8. Implement rule engine SQL functions
9. Broaden to all 24 probes (normalizer summaries)
10. Implement CLI → Arena integration (upload evidence, trigger analysis, fetch results)
11. Implement markdown report renderer
12. Write boundary-level test suites (CLI integration tests, Arena integration tests)
13. End-to-end validation against a real Supabase project

### Tools to use

- Go for the CLI (`pgx`, `yaml.v3`, stdlib)
- Supabase CLI for migrations and seeds (`supabase db push`, `supabase db reset`)
- `psql` for ad-hoc SQL and debugging
- Supabase MCP only for project provisioning
- Go code generators for any contract → SQL/code translation (deterministic, no transcription)

### What to track in conversation tasks

Use conversation tasks as an ephemeral checklist. Mark each step as done. Don't write durable plan documents — the design docs serve that purpose.
