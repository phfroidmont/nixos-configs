# Foyer-Scoped OpenCode Skills Design

## Goal

Make the Foyer `context-engineering-kit` skills available in opencode for work projects under `/home/phfroidmont/Projects/foyer/**` without making them available in personal projects.

## Context

The global opencode setup is managed by `modules/ai/opencode.nix` through Home Manager. opencode supports a `skills.paths` config field and merges config files discovered while walking up from the current workspace to the worktree root. Project config overrides or extends global config without requiring all skills to be registered globally.

The Foyer kit already exists locally at `/home/phfroidmont/Projects/foyer/platform/context-engineering-kit` and contains opencode-compatible `SKILL.md` files under each Claude plugin's `skills` directory.

## Recommended Approach

Create a small global opencode plugin that conditionally mutates the loaded config. The plugin checks the active opencode directory and adds Foyer kit skill directories only when that directory is under `/home/phfroidmont/Projects/foyer`.

This avoids relying on a parent `/home/phfroidmont/Projects/foyer/opencode.json`. That file would not reliably apply to nested Foyer repositories, because opencode project config discovery stops at the current worktree root.

## Scope

The plugin applies when opencode is started inside `/home/phfroidmont/Projects/foyer/**`.

The plugin is registered globally, but it does not add Foyer skill paths for personal projects outside `/home/phfroidmont/Projects/foyer`.

The `plugins/backup` skills are intentionally excluded. They can be added later if needed, but they are not part of the initial work-project skill set.

## Implementation Shape

Add a Home Manager-managed plugin file at `${config.xdg.configHome}/opencode/plugin/foyer-skills.ts`.

Register that plugin explicitly in `programs.opencode.settings.plugin` with its generated absolute path.

The plugin should append these absolute paths to `cfg.skills.paths` only for Foyer work directories:

```text
/home/phfroidmont/Projects/foyer/platform/context-engineering-kit/plugins/angular-dev/skills
/home/phfroidmont/Projects/foyer/platform/context-engineering-kit/plugins/design/skills
/home/phfroidmont/Projects/foyer/platform/context-engineering-kit/plugins/play-dev/skills
/home/phfroidmont/Projects/foyer/platform/context-engineering-kit/plugins/scala-dev/skills
/home/phfroidmont/Projects/foyer/platform/context-engineering-kit/plugins/context-engineering/skills
```

Keep the global `programs.opencode.settings` unchanged except for any shared helper values needed to avoid hard-coded repetition.

Use absolute paths in `skills.paths` so opencode does not depend on the current repository depth under the Foyer tree.

## Error Handling

If the Foyer kit checkout is missing, opencode may not find those skill paths. The plugin should not silently register global fallback paths, because silent fallback would violate the isolation goal.

If opencode rejects the config or plugin, fix the explicit plugin registration rather than moving the skill paths into global config.

## Verification

Run a Nix evaluation or build check for the relevant Home Manager/NixOS configuration after editing.

Inspect the generated config path or activation output if feasible.

After applying the system configuration, opencode must be restarted because opencode config is loaded only at startup.
