# Run a Design Doc Trial

You are executing the trial protocol defined in `docs/trial_protocol.md`. This is a fully autonomous process — do not stop to ask for input at any point. Implement everything, then report results at the end.

## Phase 0: Setup

1. Record the current branch name and stash any uncommitted changes:
   ```
   ORIGINAL_BRANCH=$(git branch --show-current)
   git stash push -m "trial-auto-stash" (only if there are uncommitted changes)
   ```

2. Switch to main and pull latest:
   ```
   git checkout main
   git pull origin main
   ```

3. Determine the next trial number by checking existing trial branches:
   ```
   git branch -a | grep trial_ | sort | tail -1
   ```
   Increment to get `trial_NN`.

4. Create and switch to the new trial branch:
   ```
   git checkout -b trial_NN main
   ```

## Phase 1: Read the docs

Read these files in order. Do not skip any.

1. `docs/lessons_learned.md`
2. `docs/trial_protocol.md`
3. `docs/01_methodology.md`
4. `contracts/probe_registry.yaml`
5. `contracts/rules.yaml`
6. `docs/15_normalizer.md`
7. `docs/04_data_model.md`
8. `docs/09_rule_engine.md`
9. `docs/IMPLEMENTATION_PLAN.md`
10. `CLAUDE.md`, `cli/CLAUDE.md`, `arena/CLAUDE.md`

## Phase 2: Implement

Follow the implementation plan. No planning ceremony. No spec documents. No code in plans. Just implement.

### Commit discipline (CRITICAL)

Every commit MUST be either a doc commit or an implementation commit. Never mix them.

- **Doc commits:** prefix `docs:` — fix ambiguities, add missing details, update lessons learned
- **Implementation commits:** prefix `feat:`, `fix:`, `chore:`, `test:` — the actual code

When you hit ambiguity in a design doc:
1. Stop implementing
2. Fix the doc in a `docs:` commit
3. Continue implementing from the fixed doc

### Implementation order

1. **Phase 1+2 (CLI):** Go module, registry loader, probe runner, normalizer (vertical slice of 3 probes with TDD, then broaden to all 24), validator, main.go wiring, end-to-end smoke test against local PostgreSQL
2. **Phase 3 (Arena):** Supabase project (provision via MCP if needed, or reuse existing), schema migration, rule engine SQL functions, seed all 28 rules from contracts using a Go code generator and Supabase seed files, verify with synthetic evidence
3. **Phase 3+ (Integration):** CLI arena client (upload evidence, trigger analysis, fetch results), verify end-to-end
4. **Phase 4 (Reporting):** Markdown report renderer, end-to-end with real output

### Testing

- TDD for the first 3 probes (vertical slice) to lock down types and interfaces
- Boundary-level integration tests for broadening
- End-to-end validation against a real database

### Tools

- Go for the CLI (pgx, yaml.v3, stdlib)
- Supabase CLI for migrations and seeds
- `psql` for ad-hoc SQL
- Supabase MCP only for project provisioning
- Go code generators for contract-to-SQL translation

## Phase 3: Retrospective

After implementation is complete, conduct the structured retrospective. Answer these questions yourself (do not ask the user):

1. **Planning:** Was the implementation plan sufficient? Were there steps missing or in the wrong order?
2. **Doc quality:** Where did you hit ambiguity? Were all doc fixes captured as `docs:` commits?
3. **Testing:** Was the testing approach adequate? What would have caught bugs earlier?
4. **Tooling:** Were the right tools used? Any friction from tool choices?
5. **Timing:** How did effort distribute across phases? Was any phase disproportionate?

## Phase 4: Update lessons learned

Add a trial history entry to `docs/lessons_learned.md` with:
- Trial number and date
- Scope (what was attempted)
- Doc fixes (list of docs: commits and what they fixed)
- New lessons (what was learned that wasn't known before)
- Status (complete/partial)

Update the "Recommendations for Future Implementation Sessions" section if any new lessons change the recommendations.

Commit as: `docs: update lessons learned with trial NN results`

## Phase 5: Cherry-pick and cleanup

1. Identify all `docs:` commits on the trial branch:
   ```
   git log --oneline main..HEAD --grep="^docs:"
   ```

2. Cherry-pick them to main:
   ```
   git checkout main
   git cherry-pick <hash1> <hash2> ...
   git push origin main
   ```

3. Switch back to the trial branch and push it (retained for forensic comparison):
   ```
   git checkout trial_NN
   git push origin trial_NN
   ```

4. Return to the original branch and restore stashed changes:
   ```
   git checkout $ORIGINAL_BRANCH
   git stash pop (only if we stashed in Phase 0)
   ```

## Phase 6: Report

Print a summary to the user:

```
Trial NN complete.

Branch: trial_NN (retained)
Doc commits cherry-picked to main: N
Implementation commits on trial branch: N

New lessons:
- ...

Doc fixes:
- ...

Done criteria status:
- [ ] No doc ambiguities hit (or all were fixed)
- [ ] All 28 rules fire correctly
- [ ] End-to-end test passes
- [ ] Retrospective produced no new lessons → docs are solid
```
