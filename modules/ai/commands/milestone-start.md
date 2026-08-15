Start or refine the current repository-local milestone for: $ARGUMENTS

Use `.opencode/milestones/current.md` as durable state. Ensure `.opencode/milestones/` is listed in the repository's `.git/info/exclude` without removing existing entries.

If a current milestone already exists, read it first. Do not overwrite unrelated active work; ask whether to refine, close, or replace it when the intent is ambiguous.

Create or update a concise document containing:

- title and status;
- objective and non-goals;
- acceptance criteria;
- constraints and decisions;
- owned or likely files;
- implementation steps;
- verification plan;
- current progress, blockers, and handoff notes.

Confirm the objective and acceptance criteria with the user when they cannot be inferred reliably. Do not begin implementation merely because the milestone was created unless the user also requested implementation.
