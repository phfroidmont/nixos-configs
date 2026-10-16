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
in
{
  options.modules.ai.pi = {
    enable = lib.my.mkBoolOpt false;
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

      # Anthropic bills requests carrying pi's identity line as extra usage.
      services.meridian.settings.pluginConfig = [
        { path = inputs.meridian.legacyPackages.${system}.meridianPlugins.pi-scrub.path; }
      ];

      home.file = {
        ".pi/agent/extensions/meridian-session-affinity.ts".source = ./pi-meridian-session-affinity.ts;
        ".pi/agent/skills/scalive" = {
          source = ./skills/scalive;
          recursive = true;
        };
        ".pi/agent/mcp.json".text = builtins.toJSON {
          mcpServers.playwright = {
            command = "${pkgs.nodejs}/bin/npx";
            args = [
              "-y"
              "@playwright/mcp@0.0.79"
              "--executable-path=${lib.getExe pkgs.ungoogled-chromium}"
              "--isolated"
            ];
          };
        };
      };
    };
  };
}
