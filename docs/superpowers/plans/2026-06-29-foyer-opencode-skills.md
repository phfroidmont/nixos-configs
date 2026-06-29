# Foyer-Scoped OpenCode Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load Foyer `context-engineering-kit` skills in opencode only for projects under `/home/phfroidmont/Projects/foyer/**`.

**Architecture:** Keep the global opencode config as the entry point, but add a small global plugin that conditionally appends Foyer skill paths during the opencode config hook. The plugin checks the active opencode project directory before mutating `cfg.skills.paths`, so personal projects do not receive the Foyer skills.

**Tech Stack:** NixOS module, Home Manager, opencode `plugin` config, opencode TypeScript plugin hook.

## Global Constraints

- Foyer skills must be active for every project under `/home/phfroidmont/Projects/foyer/**`.
- Foyer skills must not be registered for personal projects outside `/home/phfroidmont/Projects/foyer`.
- Do not register the Foyer skill paths directly in global `programs.opencode.settings.skills.paths`.
- Exclude `plugins/backup` from the initial skill set.
- After applying config changes, opencode must be restarted because opencode loads config only at startup.

---

## File Structure

- Modify: `modules/ai/opencode.nix`
- Responsibility: keep opencode Home Manager configuration in one module; generate the conditional plugin file; register the plugin alongside the existing `superpowers` plugin.

### Task 1: Add Conditional Foyer Skills Plugin

**Files:**
- Modify: `modules/ai/opencode.nix:19-30`
- Modify: `modules/ai/opencode.nix:221-223`

**Interfaces:**
- Consumes: Home Manager `config.home.homeDirectory`, `config.xdg.configHome`, and `programs.opencode.settings.plugin`.
- Produces: `${config.xdg.configHome}/opencode/plugin/foyer-skills.ts`, an opencode plugin whose `config(cfg)` hook appends Foyer skill paths only inside `${config.home.homeDirectory}/Projects/foyer`.

- [ ] **Step 1: Add local path bindings**

Change the Home Manager `let` block in `modules/ai/opencode.nix` to define the work root, kit root, plugin path, and skill paths:

```nix
let
  playwrightMcpUserDataDir = "${config.xdg.cacheHome}/opencode/playwright-mcp";
  foyerProjectsDir = "${config.home.homeDirectory}/Projects/foyer";
  foyerKitDir = "${foyerProjectsDir}/platform/context-engineering-kit";
  foyerSkillsPlugin = "${config.xdg.configHome}/opencode/plugin/foyer-skills.ts";
  foyerSkillPaths = [
    "${foyerKitDir}/plugins/angular-dev/skills"
    "${foyerKitDir}/plugins/design/skills"
    "${foyerKitDir}/plugins/play-dev/skills"
    "${foyerKitDir}/plugins/scala-dev/skills"
    "${foyerKitDir}/plugins/context-engineering/skills"
  ];
in
```

- [ ] **Step 2: Register the plugin explicitly**

Change `programs.opencode.settings.plugin` in `modules/ai/opencode.nix` from:

```nix
plugin = [
  "superpowers@git+https://github.com/obra/superpowers.git#v6.0.3"
];
```

to:

```nix
plugin = [
  "superpowers@git+https://github.com/obra/superpowers.git#v6.0.3"
  foyerSkillsPlugin
];
```

- [ ] **Step 3: Generate the TypeScript plugin file**

Add this Home Manager file declaration near the existing `xdg.configFile."opencode/AGENTS.md".text` block in `modules/ai/opencode.nix`:

```nix
xdg.configFile."opencode/plugin/foyer-skills.ts".text = ''
  import type { Plugin } from "@opencode-ai/plugin"

  const foyerProjectsDir = ${builtins.toJSON foyerProjectsDir}
  const foyerSkillPaths = ${builtins.toJSON foyerSkillPaths}

  const isFoyerProject = (directory: string) =>
    directory === foyerProjectsDir || directory.startsWith(foyerProjectsDir + "/")

  export default (async ({ directory }) => {
    return {
      config: (cfg) => {
        if (!isFoyerProject(directory)) return

        cfg.skills ??= {}
        cfg.skills.paths ??= []

        for (const skillPath of foyerSkillPaths) {
          if (!cfg.skills.paths.includes(skillPath)) {
            cfg.skills.paths.push(skillPath)
          }
        }
      },
    }
  }) satisfies Plugin
'';
```

- [ ] **Step 4: Verify Nix syntax**

Run: `nix eval .#nixosConfigurations.stellaris.config.modules.ai.opencode.enable`

Expected: command succeeds and prints `true`.

- [ ] **Step 5: Verify the module evaluates with the generated plugin text**

Run: `nix eval .#nixosConfigurations.stellaris.config.home-manager.users.phfroidmont.xdg.configFile."opencode/plugin/foyer-skills.ts".text --raw`

Expected: command succeeds and prints TypeScript containing `const foyerProjectsDir = "/home/phfroidmont/Projects/foyer"` and all five non-backup Foyer skill paths.

- [ ] **Step 6: Commit**

Only commit if explicitly requested. If committing, use:

```bash
git add modules/ai/opencode.nix docs/superpowers/specs/2026-06-29-foyer-opencode-skills-design.md docs/superpowers/plans/2026-06-29-foyer-opencode-skills.md
git commit -m "feat: scope foyer opencode skills to work projects"
```

### Task 2: Validate Generated Behavior After Applying Nix Config

**Files:**
- No code changes.

**Interfaces:**
- Consumes: generated `${XDG_CONFIG_HOME}/opencode/plugin/foyer-skills.ts` and updated opencode settings.
- Produces: confidence that opencode will load Foyer skills under the work tree and not personal projects after restart.

- [ ] **Step 1: Apply the NixOS/Home Manager configuration**

Run the repository's normal host switch command for the current machine.

Expected: Home Manager writes `~/.config/opencode/plugin/foyer-skills.ts` and updates `~/.config/opencode/opencode.json`.

- [ ] **Step 2: Inspect the generated plugin file**

Run: `realpath ~/.config/opencode/plugin/foyer-skills.ts && rg "context-engineering-kit|isFoyerProject|plugins/backup" ~/.config/opencode/plugin/foyer-skills.ts`

Expected: output includes the generated plugin path, includes `context-engineering-kit` and `isFoyerProject`, and does not include `plugins/backup`.

- [ ] **Step 3: Restart opencode**

Quit and restart opencode from a directory under `/home/phfroidmont/Projects/foyer`.

Expected: Foyer skills appear in the available skills list for that session.

- [ ] **Step 4: Check a personal project**

Quit and restart opencode from a directory outside `/home/phfroidmont/Projects/foyer`.

Expected: Foyer kit skills from `/home/phfroidmont/Projects/foyer/platform/context-engineering-kit` do not appear solely because of this plugin.

---

## Self-Review

- Spec coverage: Task 1 implements the path-scoped plugin and excludes backup skills. Task 2 verifies generated config and runtime behavior after restart.
- Placeholder scan: no `TBD`, `TODO`, or incomplete implementation steps remain.
- Type consistency: the plugin path variable is named `foyerSkillsPlugin` in Nix; the generated TypeScript uses `foyerProjectsDir`, `foyerSkillPaths`, and `isFoyerProject` consistently.
