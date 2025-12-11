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
            model = "glm_4_5_air";
            permission = {
              bash = "ask";
              edit = "ask";
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
                };
              };
            };
            agent = {
              build = {
                mode = "primary";
                temperature = 0.4;
              };
              plan = {
                mode = "primary";
                temperature = 0.4;
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
