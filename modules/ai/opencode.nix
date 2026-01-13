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
              bash = {
                "*" = "ask";

                pwd = "allow";
                whoami = "allow";
                id = "allow";
                "uname*" = "allow";
                "date*" = "allow";

                "ls*" = "allow";

                "git status*" = "allow";
                "git diff*" = "allow";
                "git log*" = "allow";
                "git branch*" = "allow";
                "git rev-parse*" = "allow";
                "git remote -v" = "allow";

                "node -v" = "allow";
                "npm -v" = "allow";
                "python --version" = "allow";
                "pip --version" = "allow";
              };

              edit = "ask";

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
                  glm_4_5_air = {
                    name = "GLM 4.5 Air (local)";
                    temperature = true;
                    default = true;
                  };

                  minimax_m2_1 = {
                    name = "MiniMax M2.1 (local)";
                    temperature = true;
                    default = true;
                  };
                };
              };
              openai = {
                models = {
                  "gpt-5.1-codex" = {
                    options = {
                      store = false;
                      # reasoningEffort = "high";
                      # textVerbosity = "medium";
                      # reasoningSummary = "auto";
                      include = [ "reasoning.encrypted_content" ];
                    };
                  };
                  "gpt-5.1-codex-max" = {
                    options = {
                      store = false;
                      include = [ "reasoning.encrypted_content" ];
                    };
                  };
                };
              };
            };
            agent = {
              build = {
                mode = "primary";
                temperature = 0.1;
                prompt = "{file:${./prompts/basic-rules.txt}}";
              };
              plan = {
                mode = "primary";
                temperature = 0.4;
              };
              debug = {
                disable = false;
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
