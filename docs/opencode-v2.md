# OpenCode V2

OpenCode is pinned through `llm-agents` (`opencode2` 2.0.17), exposed as
`opencode`, and uses its shared background service. Nix controls upgrades.

The wrapper supplies Wayland/X11 libraries for V2's native clipboard backend;
image paste uses `Ctrl+V`. Version 2.0.17's ChatGPT integration applies a legacy
400,000 total / 272,000 input cap to every model. `openai-model-limits.json`
records the models.dev limits audited on 2026-09-30; Nix applies them to all 18
currently enabled OpenAI entries, including fast and ultrafast service tiers.

| Models | Total context | Input limit | Maximum output |
| --- | ---: | ---: | ---: |
| GPT-5.5, GPT-5.6 Luna/Sol/Terra, GPT-6 Astra/Luna/Sol, GPT-6.1 Sol (including aliases) | 1,050,000 | 922,000 | 128,000 |
| GPT-5.3 Codex Spark | 128,000 | 100,000 | 32,000 |

Anthropic context limits come from Meridian's live subscription inventory.
The newer Opus/Fable models currently advertise 1,000,000 tokens; Sonnet
4.6/5/5.5 advertises 200,000 for the subscription route, despite models.dev's
1M direct-API limits. Output limits still come from the model catalog. Do not
override subscription discovery with API-tier context sizes.

After provider/model updates, run `oc-check-model-limits`. It compares every
enabled OpenAI/Anthropic model's effective context, input, and output limits
against the current models.dev catalog and Meridian's `/v1/models`, resolving
aliases via their underlying model IDs. Unknown models, changed limits, and
incomplete inventories fail the audit rather than silently passing. Refresh
the recorded OpenAI limits when the audit identifies new or changed models;
this snapshot does not claim to know the limits of future releases.

## First cutover from V1

1. Finish and close **all V1 OpenCode sessions**. Do not run V1 and V2 against
   the same database during or after migration.
2. Build and activate the NixOS configuration from a normal shell:

   ```sh
   sudo nixos-rebuild switch --flake path:.#stellaris
   ```

3. Before starting V2 for the first time, run:

   ```sh
   oc-migrate-v2
   ```

   This takes a consistent SQLite backup next to `opencode.db`, named
   `opencode-before-v2-<UTC timestamp>.db`. It then fills missing metadata in
   old V1 messages: assistant `agent` comes from the recorded `mode`, and a
   user's model/agent comes from its recorded assistant reply. Text, tool
   results, timestamps, costs, and token counts are not changed.

   An unanswered legacy prompt has no historical model to recover. It is
   retained with `legacy/unknown`; select a current profile/model to resume it.

4. Start `oc`. V2 migrates the prepared history on first server startup. Inspect
   `opencode service status` or the migration progress if this takes a while.
   Resume existing sessions with `oc --session <id>` or `oc --continue`.

The September 30 migration rehearsal used a consistent snapshot of the actual
history: all **5,218 session IDs/titles** and all recorded cost/token totals
reconciled after preparing 58 old messages. The usage widget also reconciled
all **327 provider/model/day buckets**, without counting migrated rows twice.

The backup is for rollback to the cutover point, not a way to bring later V2
messages back to V1. Stop V2 before restoring it; restore the database and its
matching V1 configuration/package together. Never replace a running SQLite
database or mix its old `-wal`/`-shm` sidecars with a restored database.

## Launching sessions

```sh
oc
oc --profile premium
oc --profile anthropic --review-model opus
oc --agents stock --profile openai
oc --no-auto
oc --profile premium -- run 'Explain this project'
oc --profile balanced --session <id>
```

`--profile`, `--agents`, and `--review-model` are **session selections**. They
are stored in session metadata; opening a second client does not rewrite the
first client's configuration. Resuming without selectors preserves the stored
profile and selected model. An explicit `--profile` changes the primary model;
changing only the reviewer does not reset a model selected in the TUI.

- Custom suites use private, profile-specific agent IDs. A server plugin maps
  the familiar subagent aliases (`review`, `scout`, `implement`, etc.) to the
  selected suite. Permissions are native agent rules, applied after shared
  permissions. Delegation instructions are appended only for custom primary
  agents, without replacing the model's default system prompt.
- Stock mode uses native/project agent definitions and routes built-in
  subagents to the selected profile's models. Project-defined agents remain
  project-defined.
- Build/Plan switching retains the session's suite. New sessions opened using
  the native TUI's new-session action start with the configured balanced custom
  default; use `oc` to select another initial suite.
- Compaction uses the session model in V2. Title generation uses the globally
  configured small model. There is no separate per-profile compaction model.
- `--power` has been removed. The unused Neovim OpenCode integration is removed;
  Metals/MCP remain configured.

`OPENCODE_CONFIG_CONTENT` is server-wide in V2 and is no longer a supported
per-launch overlay for `oc`. Put shared settings in Nix and project settings in
`opencode.json(c)`. `oc` deliberately rejects inherited nonempty inline config
for session launches. Use a fresh shell after upgrading from a V1 agent shell.

The native command remains available for service management and diagnostics:

```sh
opencode service status
opencode service restart
opencode stats --cost
opencode stats --models
opencode --standalone
```

`oc` profiles target the shared service (or an explicitly selected `--server`).
Standalone is available through the native `opencode` command. Shared local
clients send their environment with session work; remote `--server` connections
follow V2's remote-server environment semantics.

## Herdr and provider integration

Herdr 0.9.3's V2 CLI plugin owns pane selection and status reporting. It lives
in `cli.json`; V1's server-state plugin and TUI registration are removed. Herdr
restores `opencode --session ...` through `oc`, retaining the session metadata.
Tabs use `auto`, so V2 hides its tab bar inside Herdr.

### Split-diff memory exhaustion workaround

OpenCode 2.0.17 bundles the OpenTUI 0.5.12 split-diff rebuild bug
([OpenTUI #1543](https://github.com/anomalyco/opentui/issues/1543),
[OpenCode #51761](https://github.com/anomalyco/opencode/issues/51761)). Layout
changes can leave a pane width as `NaN`, repeatedly queueing diff rebuilds
without yielding to the event loop. Replacing text also retains old native rope
allocations, so the client can exhaust RAM and swap while the shared service
remains healthy. It is not specific to a project or model.

`modules/desktop/herdr.nix` forces `diffs.view = "unified"` in `cli.json`,
including inline edit/patch diffs, to bypass the affected split-view path.
Keep this workaround until the installed OpenCode bundles both upstream fixes:
[OpenTUI #1544](https://github.com/anomalyco/opentui/pull/1544) and
[OpenTUI #1545](https://github.com/anomalyco/opentui/pull/1545).

The CLI reloads this setting without restarting the shared service. A client
already frozen in the rebuild loop still needs to be killed and reopened;
its event loop cannot process configuration changes or profiling signals.

Meridian is updated to its V2-capable release and loads the explicit
`dist/meridian-v2` package. Meridian uses its own compatible Claude Code runtime.
Foyer skill directories are configured at `~/Projects/foyer/opencode.json` and
inherited by projects beneath it.

## Usage widget

The Claude and Codex collectors use a connection-local, read-only usage view:

- Retain V1 `message` records as authoritative historical usage.
- Include V2 `session_message` assistant records whose IDs are not in V1.
- Normalize V2 model/token fields to the existing collector format.

This preserves compaction usage and avoids migrated-message duplicates. It
also supports V1-only and V2-only databases. Collector cache versions change
at cutover. Claude SDK transcripts remain excluded to avoid double-counting
Meridian traffic. Provider quota/reset queries are independent of this view.

## Verification

```sh
nix build --no-link path:.#checks.x86_64-linux.opencode-review
nix build --no-link path:.#nixosConfigurations.stellaris.config.home-manager.users.phfroidmont.home.activationPackage
```

The profile check exercises scoped permissions, model routing, stock/custom
instructions, launcher resume behavior, metadata repair, and completion.
The Quickshell package build tests the V1/V2 usage view and the actual collectors.
