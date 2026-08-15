Close the current milestone described in `.opencode/milestones/current.md`.

Read the milestone and inspect the actual worktree. Verify each acceptance criterion using existing evidence or the narrowest relevant checks. Do not mark unmet criteria complete; report the gap and keep the milestone open unless the user explicitly accepts it.

When the milestone is complete:

- record the outcome, important decisions, changed files, verification, residual risks, and follow-ups;
- set its status to completed with the current date;
- move it to `.opencode/milestones/archive/YYYY-MM-DD-<short-name>.md`;
- leave no `current.md` behind;
- return a concise handoff summary.

Do not commit, push, or delete unrelated milestone history.
