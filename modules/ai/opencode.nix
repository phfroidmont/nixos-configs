{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ai.opencode;
in
{
  options.modules.ai.opencode = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} =
      { config, ... }:
      let
        playwrightMcpUserDataDir = "${config.xdg.cacheHome}/opencode/playwright-mcp";
      in
      {
        programs.opencode = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.system}.opencode;
          settings = {
            model = "minimax_m2_1";
            permission = {
              external_directory = {
                "*" = "ask";
                "/nix/store/**" = "allow";
                "~/Projects/**" = "allow";
              };

              bash = {
                "*" = "ask";

                pwd = "allow";
                whoami = "allow";
                id = "allow";
                "uname*" = "allow";
                "date*" = "allow";
                "ls*" = "allow";
                "stat*" = "allow";
                "readlink*" = "allow";
                "realpath*" = "allow";
                "tree*" = "allow";
                "du -sh*" = "allow";
                "rg*" = "allow";
                "fd*" = "allow";
                "find*" = "allow";
                "cat*" = "allow";
                "head*" = "allow";
                "wc*" = "allow";
                "tail*" = "allow";
                "sort*" = "allow";
                "uniq*" = "allow";
                "cut*" = "allow";

                "git status*" = "allow";
                "git diff*" = "allow";
                "git log*" = "allow";
                "git show*" = "allow";
                "git ls-files*" = "allow";
                "git blame*" = "allow";
                "git branch*" = "allow";
                "git tag*" = "allow";
                "git rev-parse*" = "allow";
                "git symbolic-ref*" = "allow";
                "git remote -v" = "allow";

                "node -v" = "allow";
                "npm -v" = "allow";
                "npx prettier*" = "allow";
                "npx eslint*" = "allow";
                "mill*" = "allow";
                "sbt*" = "allow";
                "python --version" = "allow";
                "pip --version" = "allow";
                "nix --version" = "allow";

                "nix path-info*" = "allow";
                "nix-store --query*" = "allow";
                "nix-store -q*" = "allow";
                "nix eval*" = "allow";
                "nix search*" = "allow";
                "nix flake show*" = "allow";

                "git commit*" = "ask";
                "git push*" = "ask";
                "npm install*" = "ask";
                "nixos-rebuild*" = "ask";
                "systemctl*" = "ask";
                "rm *" = "ask";
              };

              edit = {
                "*" = "ask";
                "/nix/store/**" = "deny";
                "/run/current-system/**" = "deny";
                "/nix/var/nix/profiles/system/**" = "deny";
                "/etc/static/**" = "deny";
              };

              skill = {
                "*" = "allow";
              };
            };
            provider = {
              vllm = {
                npm = "@ai-sdk/openai-compatible";
                name = "vLLM";

                options = {
                  baseURL = "http://model1.lefoyer.lu:8030/v1";
                  apiKey = "dummy";
                };

                models = {
                  minimax_m2_1 = {
                    name = "MiniMax M2.1 (local)";
                    temperature = true;
                    default = true;
                  };
                };
              };
            };
            agent = {
              build = {
                mode = "primary";
                temperature = 0.1;
              };
              plan = {
                mode = "primary";
                temperature = 0.4;
              };
              debug = {
                disable = false;
                temperature = 0.15;
                prompt = "{file:${./prompts/debug-rules.txt}}";
                permission = {
                  edit = "deny";
                  task = {
                    "*" = "deny";
                    "explore" = "allow";
                    "general" = "ask";
                  };
                };
              };
              review = {
                disable = false;
              };
            };
            mcp = {
              metals = {
                type = "local";
                command = [
                  "metals-mcp"
                  "--workspace"
                  "."
                  "--transport"
                  "stdio"
                ];
                enabled = false;
              };
              dstudiodoc = {
                type = "remote";
                url = "http://iavideotranslation.lefoyer.lu:7860/mcp/";
                enabled = false;
                timeout = 10000;
              };
              chrome-devtools = {
                type = "local";
                command = [
                  "${pkgs.nodejs}/bin/npx"
                  "-y"
                  "chrome-devtools-mcp@latest"
                  "--executable-path=${lib.getExe pkgs.ungoogled-chromium}"
                ];
                enabled = false;
                timeout = 60000;
              };
              playwright = {
                type = "local";
                command = [
                  "${pkgs.nodejs}/bin/npx"
                  "-y"
                  "@playwright/mcp@latest"
                  "--executable-path=${lib.getExe pkgs.ungoogled-chromium}"
                  "--user-data-dir=${playwrightMcpUserDataDir}"
                ];
                enabled = true;
                timeout = 60000;
              };
            };
          };
        };
        xdg.configFile."opencode/AGENTS.md".text = ''
          # Global OpenCode Rules

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
          - For bugs, write a failing regression test first, then fix.
          - Log important branches with enough context (e.g., request/correlation IDs) for production debugging.

          ## Commits
          - Use Conventional Commits
          - Before any commit, try to run the project formatter and linter on changed files.
        '';
        home.packages = with pkgs; [
          metals
        ];
      };
  };
}
