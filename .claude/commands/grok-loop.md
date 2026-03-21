# Grok Loop

Run `/grok` a fixed number of times, sequentially. Each run completes fully before the next one starts. No time-based scheduling, no race conditions.

## Usage

The argument to this command is the number of iterations. If no argument is provided, default to 3.

## What To Do

Parse the iteration count from the argument: $ARGUMENTS

If the argument is empty or not a positive integer, default to 3.

### Run the passes

Maintain an array of "new items found" counts, one per pass.

For each iteration (1 through N):

1. Announce: `### Grok pass [X] of [N]`
2. Invoke the `/grok` skill using the Skill tool
3. Wait for it to complete fully (the subagent finishes, commits, and returns its report)
4. Parse the `NEW_ITEMS=[N]` line from the first line of the subagent's response. Record that number for this pass.
5. Briefly announce: `Pass [X]: [N] new items found`
6. Only then proceed to the next iteration

### Summarize and Graph

After all passes complete, read `docs/grok-log.md` and produce a distilled summary plus a convergence graph.

The convergence graph is an ASCII bar chart showing new items found per pass. Render it like this example (for a 5-pass run that found 7, 4, 3, 1, 1 new items):

```
New items found per pass (target: 0)

  Pass 1 │████████████████████████████ 7
  Pass 2 │████████████████ 4
  Pass 3 │████████████ 3
  Pass 4 │████ 1
  Pass 5 │████ 1
         └─────────────────────────────
```

Scale the bars proportionally to the maximum value. Use `█` characters. Each bar should be at least 1 `█` wide if the count is > 0. A count of 0 shows no bar, just the number:

```
  Pass 6 │ 0
```

If the trend is decreasing, add a note: `Trend: converging` followed by a thumbs-up emoji.
If the trend is flat or increasing, add: `Trend: not yet converging — consider reviewing docs/RESIDUALS.md`

Present the full output to the user in this order:

```
## Grok Loop Complete — [N] passes

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
- Each `/grok` invocation spawns its own fresh subagent — no context carries between passes.
- If a pass fails (subagent errors out), record its new-items count as `?`, log the failure, and continue to the next pass. Don't abort the whole loop.
- Do NOT push to remote. The user will push when ready.
- The per-pass raw summaries live in `docs/grok-log.md`. Don't repeat them verbatim — distill them.
