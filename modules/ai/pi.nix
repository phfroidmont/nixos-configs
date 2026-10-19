{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ai.pi;
  system = pkgs.stdenv.hostPlatform.system;

  # Headless Metals over stdio for one worktree, started by pi-metals.ts.
  metalsMcpWorktree = pkgs.writeShellApplication {
    name = "metals-mcp-worktree";
    runtimeInputs = [ pkgs.direnv ];
    text = ''
      workspace="''${1:-$PWD}"
      # In the worktree's dev shell, so Metals drives the project's own Mill:
      # without --mill-script it downloads a generic Mill that NixOS cannot run,
      # and without --default-bsp-to-build-tool it starts Bloop next to Mill.
      # shellcheck disable=SC2016
      exec direnv exec "$workspace" sh -c '
        mill="$(command -v mill)" || { echo "metals-mcp-worktree: no mill in the dev shell of $1" >&2; exit 1; }
        exec ${lib.getExe' pkgs.metals "metals-mcp"} --workspace "$1" --transport stdio \
          --default-bsp-to-build-tool --mill-script "$mill"
      ' metals-mcp-worktree "$workspace"
    '';
  };

  hm = config.home-manager.users.${config.user.name};
  foyerProjectsDir = "${hm.home.homeDirectory}/Projects/foyer";
  # OpenCode loads Foyer's skills in Foyer projects through this project file.
  foyerSkillPaths = (builtins.fromJSON hm.home.file."Projects/foyer/opencode.json".text).skills;

  c = (import ../desktop/themes/_palette.nix).hex;
  # The default theme derives its colors from the terminal and tints every tool
  # panel olive. Markdown and syntax take the roles of OpenCode's gruvbox theme.
  gruvboxTheme = {
    "$schema" = "https://pi.dev/schemas/theme.schema.json";
    name = "gruvbox";
    appearance = "dark";
    colors = {
      accent = c.orange;
      border = c.bg3;
      borderAccent = c.orange;
      borderMuted = c.bg2;
      success = c.green;
      error = c.red;
      warning = c.yellow;
      muted = c.fg4;
      dim = c.gray;
      text = c.fg1;
      thinkingText = c.gray;
      scrollbarTrack = c.bg1;
      scrollbarThumb = c.bg3;
      selectedBg = c.bg2;
      userMessageBg = c.bg1;
      userMessageText = c.fg1;
      customMessageBg = c.bg0Soft;
      customMessageText = c.fg4;
      customMessageLabel = c.purple;
      toolPendingBg = c.bg0Soft;
      toolSuccessBg = c.bg0Soft;
      # Gruvbox has no red background: redDark at 20% over bg0.
      toolErrorBg = "#492726";
      toolTitle = c.fg1;
      toolOutput = c.fg4;
      mdHeading = c.blue;
      mdLink = c.green;
      mdLinkUrl = c.aqua;
      mdCode = c.yellow;
      mdCodeBlock = c.fg1;
      mdCodeBlockBorder = c.gray;
      mdQuote = c.gray;
      mdQuoteBorder = c.gray;
      mdHr = c.gray;
      mdListBullet = c.blue;
      toolDiffAdded = c.green;
      toolDiffRemoved = c.red;
      toolDiffContext = c.gray;
      syntaxComment = c.gray;
      syntaxKeyword = c.red;
      syntaxFunction = c.green;
      syntaxVariable = c.blue;
      syntaxString = c.yellow;
      syntaxNumber = c.purple;
      syntaxType = c.aqua;
      syntaxOperator = c.orange;
      syntaxPunctuation = c.fg1;
      # The editor border shows the thinking level.
      thinkingOff = c.bg3;
      thinkingMinimal = c.gray;
      thinkingLow = c.blue;
      thinkingMedium = c.aqua;
      thinkingHigh = c.purple;
      thinkingXhigh = c.orange;
      thinkingMax = c.red;
      bashMode = c.green;
    };
  };
in
{
  options.modules.ai.pi = {
    enable = lib.mkEnableOption "the pi coding agent";
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.ai.opencode.enable;
        message = "modules.ai.pi reaches Claude through Meridian, which modules.ai.opencode runs.";
      }
    ];

    home-manager.users.${config.user.name} = {
      programs.pi-coding-agent = {
        enable = true;
        package = inputs.llm-agents.packages.${system}.pi;
        # Nix owns this file: pi logs and skips its own writes (/settings, Ctrl+S defaults).
        settings = {
          defaultProvider = "anthropic";
          defaultModel = "claude-opus-5-5";
          # Each bash call is a fresh `bash -c` that never runs the direnv hook.
          # Loads the folder's .envrc (and later .envrc/flake.nix changes) per
          # command; cheap when the env is already inherited, a no-op without .envrc.
          shellCommandPrefix = ''eval "$(direnv export bash 2>/dev/null)"'';
          theme = "gruvbox";
          # Ctrl+T shows thinking; `pi --verbose` lists the loaded resources at startup.
          hideThinkingBlock = true;
          quietStartup = true;
          # The Claude account's skills, which Claude Code syncs and OpenCode loads.
          # The excluded ones drive tools of the Claude apps or spawn subagents.
          skills = [
            "~/.claude/skills/synced"
          ]
          ++ map (name: "!${name}") [
            "built-in-browser"
            "chrome-browser"
            "computer-use"
            "deep-research"
            "docs"
            "google-workspace"
            "import-memory"
            "morning"
          ];
        };
        models.providers = {
          # Meridian serves the Claude subscription. For Opus 5.5 and Haiku 5.5,
          # pi's catalog limits match Meridian's inventory: no overrides needed.
          anthropic = {
            baseUrl = "http://127.0.0.1:3456";
            apiKey = "x";
            headers."x-meridian-agent" = "pi";
          };
          # Pi's catalog caps most GPT models at 272K. Use OpenCode's audited limits.
          # Compaction keeps the prompt below contextWindow, so it takes the input limit.
          openai.modelOverrides = lib.mapAttrs (_: limit: {
            contextWindow = limit.input;
            maxTokens = limit.output;
          }) (builtins.fromJSON (builtins.readFile ./openai-model-limits.json));
        };
        context = ''
          # Global Pi Rules

          ${builtins.readFile ./prompts/global-rules.md}
        '';
      };

      services.meridian = {
        # Anthropic bills requests carrying pi's identity line as extra usage.
        settings.pluginConfig = [
          { path = inputs.meridian.legacyPackages.${system}.meridianPlugins.pi-scrub.path; }
        ];
        # Meridian appends a "Files changed" list to pi's replies, which pi already shows
        # as tool calls; OpenCode's and Claude Code's adapters opt out of it themselves.
        environment.MERIDIAN_NO_FILE_CHANGES = "1";
      };

      home.packages = [ metalsMcpWorktree ];

      home.file = {
        ".pi/agent/extensions/meridian-session-affinity.ts".source = ./pi-meridian-session-affinity.ts;
        ".pi/agent/extensions/metals.ts".source = ./pi-metals.ts;
        ".pi/agent/extensions/compact-tools.ts".source = ./pi-compact-tools.ts;
        ".pi/agent/extensions/mcp-approval.ts".source = ./pi-mcp-approval.ts;
        # Registered rather than listed in mcp.json, which Nix links read-only:
        # /mcp can then enable a server for the session without writing a file.
        ".pi/agent/extensions/mcp-servers.ts".text = ''
          import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

          const servers = ${builtins.toJSON (import ./_mcp-servers.nix { inherit lib pkgs; })};

          export default function (pi: ExtensionAPI) {
            for (const [name, server] of Object.entries(servers)) pi.registerMcpServer(name, server);
          }
        '';
        ".pi/agent/extensions/foyer-skills.ts".text = ''
          import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

          export default function (pi: ExtensionAPI) {
            pi.on("resources_discover", (event) => {
              if (`''${event.cwd}/`.startsWith(${builtins.toJSON "${foyerProjectsDir}/"})) {
                return { skillPaths: ${builtins.toJSON foyerSkillPaths} };
              }
            });
          }
        '';
        ".pi/agent/themes/gruvbox.json".text = builtins.toJSON gruvboxTheme;
        ".pi/agent/skills/scalive" = {
          source = ./skills/scalive;
          recursive = true;
        };
      };
    };
  };
}
