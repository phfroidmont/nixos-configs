## Code Style
Rule 0: Complexity is the main failure mode. Keep it boring.
- Prefer the simplest solution that works; avoid unnecessary features, layers, and abstractions.
- Make illegal states unrepresentable whenever possible
- Write for humans first: clear names, explicit control flow, and readable code over clever code.
- Break complex expressions into small, named steps; optimize for debuggability.
- Keep behavior local to where it is used; avoid needless indirection across files/modules.
- Accept small duplication when it is clearer than a “smart” abstraction.
- Add abstractions only after patterns are proven and stable (never speculative).
- Respect existing code: understand why it exists before replacing it (Chesterton’s Fence).
- For bugs, reproduce first and identify the root cause before changing code; add a failing regression test, then fix.
- Log important branches with enough context (e.g., request/correlation IDs) for production debugging.

## Commits
- Use Conventional Commits
- Before any commit, try to run the project formatter and linter on changed files.

## Filesystem
- Search known dependency caches directly; never glob or search all of `~/.cache`.
