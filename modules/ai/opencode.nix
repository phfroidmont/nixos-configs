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
        foyerProjectsDir = "${config.home.homeDirectory}/Projects/foyer";
        foyerKitDir = "${foyerProjectsDir}/platform/context-engineering-kit";
        foyerSkillsPlugin = "${config.xdg.configHome}/opencode/plugin/foyer-skills.ts";
        jiraMcp = pkgs.writeShellApplication {
          name = "mcp-atlassian-jira";
          runtimeInputs = [
            pkgs.libsecret
            pkgs.uv
          ];
          text = ''
            if ! jiraPersonalToken="$(secret-tool lookup application opencode service jira.foyer.lu)"; then
              echo "Unable to retrieve the Jira PAT from Secret Service" >&2
              exit 1
            fi

            if [[ -z "$jiraPersonalToken" ]]; then
              echo "The Jira PAT retrieved from Secret Service is empty" >&2
              exit 1
            fi

            export JIRA_PERSONAL_TOKEN="$jiraPersonalToken"
            exec uvx mcp-atlassian==0.23.0
          '';
        };
        jiraToolsets = [
          "jira_issues"
          "jira_fields"
          "jira_comments"
          "jira_transitions"
          "jira_projects"
          "jira_agile"
          "jira_links"
          "jira_worklog"
          "jira_attachments"
          "jira_users"
          "jira_watchers"
          "jira_forms"
          "jira_metrics"
          "jira_development"
          "jira_project_analysis"
        ];
        readOnlyBash = {
          "*" = "deny";
          pwd = "allow";
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
        };
        foyerConfig = builtins.toJSON {
          mcp.jira.enabled = true;
        };
        superpowersConfig = builtins.toJSON {
          plugin = [ "superpowers@git+https://github.com/obra/superpowers.git#v6.0.3" ];
        };
        foyerSkillPaths = [
          "${foyerKitDir}/plugins/angular-dev/skills"
          "${foyerKitDir}/plugins/design/skills"
          "${foyerKitDir}/plugins/play-dev/skills"
          "${foyerKitDir}/plugins/scala-dev/skills"
          "${foyerKitDir}/plugins/context-engineering/skills"
        ];
      in
      {
        programs.opencode = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.system}.opencode;
          settings = {
            model = "openai/gpt-5.6-sol";
            small_model = "openai/gpt-5.6-luna";
            default_agent = "build";
            subagent_depth = 1;
            compaction = {
              auto = true;
              prune = false;
              reserved = 32000;
              tail_turns = 4;
              preserve_recent_tokens = 12000;
            };
            tool_output = {
              max_lines = 400;
              max_bytes = 24576;
            };
            plugin = [ foyerSkillsPlugin ];
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
                  };
                };
              };
            };
            agent = {
              build = {
                description = "Primary implementation agent and orchestrator for coding work.";
                mode = "primary";
                model = "openai/gpt-5.6-sol";
                permission.task = {
                  "*" = "deny";
                  explore = "allow";
                  scout = "allow";
                  test-triage = "allow";
                  scan = "allow";
                  review = "allow";
                  implement = "allow";
                };
              };
              plan = {
                description = "Read-only planning and architectural analysis.";
                mode = "primary";
                model = "openai/gpt-5.6-sol";
                permission = {
                  edit = "deny";
                  bash = readOnlyBash;
                  task = {
                    "*" = "deny";
                    explore = "allow";
                    scout = "allow";
                    test-triage = "allow";
                    scan = "allow";
                    review = "allow";
                  };
                };
              };
              debug = {
                description = "Read-only primary agent for difficult, evidence-driven debugging.";
                disable = false;
                mode = "primary";
                model = "openai/gpt-5.6-sol";
                prompt = "{file:${./prompts/debug-rules.txt}}";
                permission = {
                  edit = "deny";
                  task = {
                    "*" = "deny";
                    "explore" = "allow";
                    "scout" = "allow";
                    "test-triage" = "allow";
                    "scan" = "allow";
                  };
                };
              };
              explore = {
                description = "Read-only codebase exploration that returns concise evidence and file references.";
                mode = "subagent";
                model = "openai/gpt-5.6-terra";
                steps = 100;
                permission = {
                  edit = "deny";
                  bash = readOnlyBash;
                  task = "deny";
                };
              };
              scout = {
                description = "Read-only dependency and external documentation research.";
                mode = "subagent";
                model = "openai/gpt-5.6-terra";
                steps = 100;
                permission = {
                  edit = "deny";
                  task = "deny";
                };
              };
              test-triage = {
                description = "Reproduces and analyzes test failures without modifying source files.";
                mode = "subagent";
                model = "openai/gpt-5.6-terra";
                steps = 100;
                prompt = "{file:${./prompts/test-triage-rules.txt}}";
                permission = {
                  edit = "deny";
                  task = "deny";
                };
              };
              scan = {
                description = "Performs narrow mechanical searches, inventories, and consistency checks.";
                mode = "subagent";
                model = "openai/gpt-5.6-luna";
                steps = 100;
                prompt = "{file:${./prompts/scan-rules.txt}}";
                permission = {
                  edit = "deny";
                  bash = "deny";
                  task = "deny";
                };
              };
              review = {
                description = "Reviews changes for defects, regressions, risks, and missing tests without editing.";
                disable = false;
                mode = "subagent";
                model = "openai/gpt-5.6-sol";
                steps = 100;
                prompt = "{file:${./prompts/review-rules.txt}}";
                permission = {
                  edit = "deny";
                  bash = readOnlyBash;
                  task = "deny";
                };
              };
              implement = {
                description = "Implements one explicitly bounded, disjoint file scope assigned by the primary agent.";
                mode = "subagent";
                model = "openai/gpt-5.6-sol";
                steps = 100;
                prompt = "{file:${./prompts/implement-rules.txt}}";
                permission = {
                  edit = "allow";
                  task = "deny";
                  bash = {
                    "git commit*" = "deny";
                    "git push*" = "deny";
                  };
                };
              };
              general.disable = true;
              compaction.model = "openai/gpt-5.6-sol";
              title.model = "openai/gpt-5.6-luna";
              summary.model = "openai/gpt-5.6-luna";
            };
            command = {
              milestone-start = {
                description = "Start or refine durable repository-local milestone state.";
                agent = "build";
                model = "openai/gpt-5.6-sol";
                template = "{file:${./commands/milestone-start.md}}";
              };
              milestone-close = {
                description = "Verify, summarize, and archive the current milestone.";
                agent = "build";
                model = "openai/gpt-5.6-sol";
                template = "{file:${./commands/milestone-close.md}}";
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
                  "@playwright/mcp@0.0.79"
                  "--executable-path=${lib.getExe pkgs.ungoogled-chromium}"
                  "--user-data-dir=${playwrightMcpUserDataDir}"
                ];
                enabled = true;
                timeout = 60000;
              };
              jira = {
                type = "local";
                command = [ "${jiraMcp}/bin/mcp-atlassian-jira" ];
                environment = {
                  JIRA_URL = "https://jira.foyer.lu/";
                  TOOLSETS = lib.concatStringsSep "," jiraToolsets;
                };
                enabled = false;
                timeout = 60000;
              };
            };
          };
        };
        programs.zsh.shellAliases = {
          oc = "opencode";
          oc-foyer = "OPENCODE_CONFIG_CONTENT=${lib.escapeShellArg foyerConfig} opencode";
          oc-power = "OPENCODE_CONFIG_CONTENT=${lib.escapeShellArg superpowersConfig} opencode";
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

          ## Delegation
          - Delegate only bounded, independent work with an explicit expected report.
          - Prefer read-only agents for exploration, dependency research, test triage, scans, and review.
          - Concurrent writer agents may share a worktree only when assigned disjoint files or directories.
          - Give every writer exact ownership boundaries. Stop and ask if scopes overlap or unexpected edits appear.
          - The primary agent reviews and integrates writer results. Subagents do not commit, push, or delegate further.
          - Subagents return concise findings, changed files, verification, and unresolved risks instead of raw output.

          ## Milestones
          - Treat compaction as a safety mechanism, not durable project memory.
          - For substantial multi-session work, keep objectives, acceptance criteria, decisions, status, verification, and handoff notes in `.opencode/milestones/current.md`.
          - Keep milestone state current at meaningful boundaries and before ending a session.
        '';
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
        home.packages = with pkgs; [
          metals
        ];
      };
  };
}
