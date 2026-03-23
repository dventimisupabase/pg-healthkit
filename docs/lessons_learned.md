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

### PG version compatibility

- Test probes against PG 15, 16, and 17 at minimum. PG 17 restructured `pg_stat_bgwriter` into separate `pg_stat_checkpointer` and `pg_stat_bgwriter` views.
- Probes that query system catalog views should use version-aware SQL (e.g., `DO $$ IF current_setting('server_version_num')::int >= 170000 THEN ... END IF; $$`) for cross-version compatibility.
- The pgx driver returns PostgreSQL `numeric` as `pgtype.Numeric`, not Go `float64`. Handle this explicitly in type coercion.

### What to track in conversation tasks

Use conversation tasks as an ephemeral checklist. Mark each step as done. Don't write durable plan documents — the design docs serve that purpose.

## Trial History

### Trial 01 — 2026-03-21

**Scope:** Full v1 implementation (Phases 1-5). All 24 probes, all 28 rules, CLI with arena integration, markdown reporting.

**Doc fixes:**
- `docs: strip Go code examples from design docs` — removed illustrative Go interfaces from `15_normalizer.md` and all Go code from `IMPLEMENTATION_PLAN.md`. Replaced with prose and an 8-step checklist.
- `docs: merge Phase 1 implementation tasks into IMPLEMENTATION_PLAN.md` — consolidated the plan into one document (later stripped of code).
- `CLAUDE.md` updated to specify Go as CLI language.

**New lessons:**
- Heavyweight planning ceremony (brainstorm → spec → plan → reviews) is disproportionate when design docs are thorough. Skip it.
- Code in plans is noise. Good specs produce good code.
- Use Supabase CLI and psql for database operations, not the Supabase MCP (except for provisioning).
- Use Supabase seed files for reference data, not custom tooling.
- TDD for interfaces (vertical slice), integration tests for breadth.
- Separate doc-fix commits from implementation commits throughout the trial, not retroactively.

**Status:** Complete. All v1 Definition of Done criteria met. Retrospective produced the trial protocol (`docs/trial_protocol.md`).

### Trial 02 — 2026-03-21

**Scope:** Full v1 implementation (Phases 1-5). All 24 probes, all 28 rules, CLI with arena integration, markdown reporting. Second trial to stress-test doc quality after trial 01 fixes.

**Doc fixes:**
- `docs: fix wal_checkpoint_health probe for PG 17+ schema changes` — PG 17 moved checkpoint stats from `pg_stat_bgwriter` to `pg_stat_checkpointer`. The probe now uses a version-aware DO block with dynamic SQL to handle both layouts. This was the only ambiguity encountered.

**New lessons:**
- PostgreSQL version compatibility must be tested across major versions. PG 17 broke the `wal_checkpoint_health` probe due to catalog view restructuring. Probes that query system views should be tested against both the oldest and newest supported PG versions.
- Multi-statement SQL probes (CREATE TEMP TABLE + DO + SELECT) require the runner to split and execute setup statements separately from the final query. pgx's `Query()` only handles single statements.
- pgx v5 returns PostgreSQL `numeric` as `pgtype.Numeric`, not as Go `float64`. The normalizer must handle this type explicitly in coercion functions or summary values will silently be zero.
- The Go seed generator approach worked well — reading `rules.yaml` and emitting SQL INSERTs is deterministic and eliminates transcription errors. All 28 rules seeded correctly on first attempt.
- The rule engine's `resolve_fact` function must navigate the full evidence payload JSONB. Uploading the canonical payload (which includes `summary` at top level) directly works because the dot-path resolution starts from the payload root.
- Design docs were significantly better than trial 01. Only one probe SQL fix was needed (vs. 3 doc fixes in trial 01). The normalizer, data model, and rule engine specs required zero fixes.

**Status:** Complete. All v1 Definition of Done criteria met. All 28 rules fire correctly against synthetic evidence. End-to-end test passes against local PostgreSQL.

### Trial 03 — 2026-03-21

**Scope:** Full v1 implementation (Phases 1-5). All 24 probes, all 28 rules, CLI with arena integration, markdown reporting. Third trial to validate doc stability — zero doc fixes expected.

**Doc fixes:** None. No ambiguities were encountered. All design docs, contracts, and specs were followed without modification.

**New lessons:**
- Previous trial migrations left artifacts on the Arena database (enum types, tables, functions). The initial schema migration should include `DROP IF EXISTS` cleanup to be idempotent across trials.
- The Supabase CLI `migration repair` command is needed when previous trial migration versions exist in the remote history but not in the local migrations directory.
- The probe runner's `sqlFile` path from the registry already includes the `probes/` prefix — the runner's base directory should be the repo root, not the probes directory, to avoid double-pathing.
- Design docs are now stable enough for zero-fix implementation. The trial protocol's done criteria of "no doc-fix commits needed" was met.

**Status:** Complete. All v1 Definition of Done criteria met. All 28 rules fire correctly against synthetic evidence (12 findings from 19 evidence records, scores computed correctly). End-to-end probe execution passes against local PostgreSQL 17. Zero doc-fix commits.

### Trial 04 — 2026-03-22

**Scope:** Full v1 implementation (Phases 1-5). All 24 probes, all 28 rules, CLI with arena integration, markdown reporting. Fourth trial to validate continued doc stability and measure implementation consistency.

**Doc fixes:** None. No ambiguities were encountered. All design docs, contracts, and specs were followed without modification.

**New lessons:**
- The `splitStatements` function for multi-statement SQL (DO blocks with `$$` dollar-quoting) needs character-level parsing rather than line-level regex. A simple state machine tracking `$$` toggle in/out of dollar-quote mode is sufficient and more robust than counting `$$` occurrences per line.
- Previous trial migrations left functions with different parameter names on the Arena database. The `CREATE OR REPLACE FUNCTION` statement cannot change parameter names, so `DROP FUNCTION IF EXISTS` must precede function creation in the migration for cross-trial idempotency.
- The Supabase CLI v2.75 lacks a `db execute` command for running arbitrary SQL against the remote database. The Supabase MCP `execute_sql` tool or psql with the project connection string are the alternatives. MCP works but has payload size limits requiring batching for large seed files.
- The Go seed generator's regex-based SQL splitting can be fragile when INSERT values contain semicolons (e.g., template strings with semicolons). A proper parser that splits on `);` followed by newline is more reliable than splitting on bare `;`.
- Full end-to-end integration (probe → normalize → upload → analyze → fetch → report) works with the Supabase anon key when RLS is disabled. For production, a service_role key or proper RLS policies would be needed.
- Design docs remain stable at four consecutive trials. The trial protocol's "done criteria" of zero doc-fix commits was met again.

**Status:** Complete. All v1 Definition of Done criteria met. All 28 rules fire correctly against synthetic evidence (13 findings from 19 evidence records, scores computed correctly with overall 65.80). End-to-end probe execution and full Arena integration pass against local PostgreSQL 17. Markdown report generated successfully. Zero doc-fix commits.

### Trial 05 — 2026-03-22

**Scope:** Full v1 implementation (Phases 1-5). All 24 probes, all 28 rules, CLI with arena integration, markdown reporting. Fifth trial to validate continued doc stability.

**Doc fixes:** None. No ambiguities were encountered. All design docs, contracts, and specs were followed without modification.

**New lessons:**
- The `run_analysis` SQL function must use `SECURITY DEFINER` when called via PostgREST RPC. Without it, PostgREST's safety checks block DELETE statements inside the function body (error: "DELETE requires a WHERE clause").
- Temp tables (`CREATE TEMP TABLE`) inside SQL functions called via PostgREST RPC can cause issues. Using inline PL/pgSQL variables for score accumulation (one variable per domain) is simpler and avoids the temp table overhead entirely.
- Previous trial functions with different return types require `DROP FUNCTION IF EXISTS` before `CREATE OR REPLACE FUNCTION`, since PostgreSQL cannot change a function's return type in place.
- The Go `pgtype.Numeric.Float64Value()` method returns a `pgtype.Float8` struct, not a raw `float64`. The caller must check `.Valid` and use `.Float64` from the returned struct.
- Design docs remain stable at five consecutive trials. Zero doc-fix commits across trials 03, 04, and 05.

**Status:** Complete. All v1 Definition of Done criteria met. All 28 rules fire correctly against synthetic evidence (18 findings from 19 evidence records, scores computed correctly with overall 54.90). End-to-end probe execution and full Arena integration pass against local PostgreSQL 17. Markdown report generated successfully. Zero doc-fix commits.

### Trial 06 — 2026-03-22

**Scope:** Full v1 implementation (Phases 1-5). All 24 probes, all 28 rules, CLI with arena integration, markdown reporting. Sixth trial to validate continued doc stability.

**Doc fixes:** None. No ambiguities were encountered. All design docs, contracts, and specs were followed without modification.

**New lessons:**
- PostgREST requires all objects in an array POST body to have identical key sets (error: "All object keys must match"). When uploading evidence records where some have `error_text` and some don't, use a pointer type (`*string`) with JSON `null` rather than `omitempty` to ensure consistent keys across all records.
- The Assessment struct's `id` field must use `omitempty` when creating via PostgREST POST, since sending an empty string for a UUID column causes a parse error. Let the database generate the UUID via `DEFAULT gen_random_uuid()`.
- Design docs remain stable at six consecutive trials. Zero doc-fix commits across trials 03, 04, 05, and 06.

**Status:** Complete. All v1 Definition of Done criteria met. All 28 rules fire correctly against synthetic evidence (16 findings from 19 evidence records, scores computed correctly with overall 56.70). End-to-end probe execution and full Arena integration pass against local PostgreSQL 17. Markdown report generated successfully. Zero doc-fix commits.
