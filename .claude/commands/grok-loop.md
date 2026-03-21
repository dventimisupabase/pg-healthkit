# Grok Loop

Run `/grok` a fixed number of times, sequentially. Each run completes fully before the next one starts. No time-based scheduling, no race conditions.

## Usage

The argument to this command is the number of iterations. If no argument is provided, default to 3.

## What To Do

Parse the iteration count from the argument: $ARGUMENTS

If the argument is empty or not a positive integer, default to 3.

Then, for each iteration (1 through N):

1. Announce: `### Grok pass [X] of [N]`
2. Invoke the `/grok` skill using the Skill tool
3. Wait for it to complete fully (the subagent finishes, commits, and returns its report)
4. Present the summary from that pass (issues found, fixed, new residuals)
5. Only then proceed to the next iteration

After all iterations complete, present a final summary:

```
## Grok Loop Complete

- **Passes completed**: N
- **Total issues auto-fixed across all passes**: [sum]
- **Total new residuals added across all passes**: [sum]
- **Residuals file**: docs/RESIDUALS.md
```

## Important

- Strictly sequential. Never start pass X+1 until pass X has fully completed and committed.
- Each `/grok` invocation spawns its own fresh subagent — no context carries between passes.
- If a pass fails (subagent errors out), log the failure and continue to the next pass. Don't abort the whole loop.
- Do NOT push to remote. The user will push when ready.
