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
      { ... }:
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
                "git remote -v" = "allow";

                "node -v" = "allow";
                "npm -v" = "allow";
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
                steps = 12;
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
            lsp = {
              metals = {
                command = [ "${pkgs.metals}/bin/metals" ];
                extensions = [
                  ".scala"
                  ".sbt"
                  ".sc"
                ];
                initialization = {
                  statusBarProvider = "log-message";
                  doctorProvider = "json";
                };
              };
            };
          };
        };
      };
  };
}
