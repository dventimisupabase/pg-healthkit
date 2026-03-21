# Grok Loop

Run `/grok` a fixed number of times, sequentially. Each run completes fully before the next one starts. No time-based scheduling, no race conditions.

## Usage

The argument to this command is the number of iterations. If no argument is provided, default to 3.

## What To Do

Parse the iteration count from the argument: $ARGUMENTS

If the argument is empty or not a positive integer, default to 3.

### Run the passes

For each iteration (1 through N):

1. Announce: `### Grok pass [X] of [N]`
2. Invoke the `/grok` skill using the Skill tool
3. Wait for it to complete fully (the subagent finishes, commits, and returns its report)
4. Do NOT present the raw per-pass summary to the user — it's already been written to `docs/grok-log.md` by the subagent
5. Only then proceed to the next iteration

### Summarize

After all passes complete, read `docs/grok-log.md` and produce a single distilled summary. This is the only output the user sees (besides the pass announcements). Structure it as:

```
## Grok Loop Complete — [N] passes

### Aggregate counts
- **Total issues found across all passes**: [sum]
- **Total auto-fixed across all passes**: [sum]
- **Total new residuals added across all passes**: [sum]

### Themes
[2-5 bullet points identifying patterns across passes. e.g., "3 of 5 passes found terminology drift between the scoring model and data model docs" or "Passes 2-4 each fixed cross-reference gaps in the probe catalog"]

### What's left
[Brief description of what remains in docs/RESIDUALS.md that needs human attention, if anything new was added]

### Raw log
Full per-pass details are in `docs/grok-log.md`.
```

## Important

- Strictly sequential. Never start pass X+1 until pass X has fully completed and committed.
- Each `/grok` invocation spawns its own fresh subagent — no context carries between passes.
- If a pass fails (subagent errors out), log the failure and continue to the next pass. Don't abort the whole loop.
- Do NOT push to remote. The user will push when ready.
- The per-pass raw summaries live in `docs/grok-log.md`. Don't repeat them verbatim — distill them.
