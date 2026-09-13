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
        claudeCode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
        meridian = inputs.meridian.packages.${pkgs.stdenv.hostPlatform.system}.meridian.override {
          claude-code = claudeCode;
        };
        foyerProjectsDir = "${config.home.homeDirectory}/Projects/foyer";
        foyerKitDir = "${foyerProjectsDir}/platform/context-engineering-kit";
        foyerSkillsPlugin = "${config.xdg.configHome}/opencode/plugin/foyer-skills.ts";
        sonarMcpJar = pkgs.fetchurl {
          url = "https://binaries.sonarsource.com/Distribution/sonarqube-mcp-server/sonarqube-mcp-server-1.26.0.4269.jar";
          sha256 = "f5cb214b948a1e2a7b2f8c64eb5da4185ab58c864cf3d7afb4a8bbb67fb76650";
        };
        sonarMcp = pkgs.writeShellApplication {
          name = "mcp-sonar-foyer";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.libsecret
          ];
          text = ''
            if ! sonarToken="$(secret-tool lookup application opencode service sonarqube.foyer.lu)"; then
              echo "Unable to retrieve the SonarQube user token from Secret Service" >&2
              exit 1
            fi

            if [[ -z "$sonarToken" ]]; then
              echo "The SonarQube user token retrieved from Secret Service is empty" >&2
              exit 1
            fi

            export SONARQUBE_TOKEN="$sonarToken"
            export STORAGE_PATH="''${XDG_STATE_HOME:-$HOME/.local/state}/sonarqube-mcp/foyer"
            mkdir -p "$STORAGE_PATH"
            exec ${pkgs.jdk21}/bin/java -jar ${sonarMcpJar}
          '';
        };
        jiraMcp = pkgs.writeShellApplication {
          name = "mcp-atlassian-jira";
          runtimeInputs = [
            pkgs.libsecret
            pkgs.python3
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
            exec uvx --python ${lib.getExe pkgs.python3} --no-python-downloads mcp-atlassian==0.23.0
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
          "true" = "allow";
          "git --version*" = "allow";
          "git status*" = "allow";
          "git diff*" = "allow";
          "git log*" = "allow";
          "git show*" = "allow";
          "git ls-files*" = "allow";
          "git ls-remote https://*" = "allow";
          "git blame*" = "allow";
          "git branch" = "allow";
          "git branch -a" = "allow";
          "git branch -r" = "allow";
          "git branch -v" = "allow";
          "git branch -vv" = "allow";
          "git branch --all" = "allow";
          "git branch --all --contains*" = "allow";
          "git branch --all --no-contains*" = "allow";
          "git branch --contains*" = "allow";
          "git branch --list*" = "allow";
          "git branch --no-contains*" = "allow";
          "git branch --points-at*" = "allow";
          "git branch --show-current" = "allow";
          "git tag" = "allow";
          "git tag -l*" = "allow";
          "git tag --contains*" = "allow";
          "git tag --list*" = "allow";
          "git tag --merged*" = "allow";
          "git tag --no-contains*" = "allow";
          "git tag --no-merged*" = "allow";
          "git tag --points-at*" = "allow";
          "git rev-parse*" = "allow";
          "git symbolic-ref HEAD" = "allow";
          "git symbolic-ref -q HEAD" = "allow";
          "git symbolic-ref -q --short HEAD" = "allow";
          "git symbolic-ref --quiet HEAD" = "allow";
          "git symbolic-ref --quiet --short HEAD" = "allow";
          "git symbolic-ref --short HEAD" = "allow";
          "git symbolic-ref --short -q HEAD" = "allow";
          "git symbolic-ref --short --quiet HEAD" = "allow";
          "git remote" = "allow";
          "git remote -v" = "allow";
          "git remote get-url*" = "allow";
          "git config --get*" = "allow";
          "git config --list*" = "allow";
          "git config get*" = "allow";
          "git config list*" = "allow";
          "git grep*" = "allow";
          "git grep*-O*" = "deny";
          "git grep*--open-files-in-pager*" = "deny";
          "git hash-object*" = "allow";
          "git hash-object*-w*" = "deny";
          "git ls-tree*" = "allow";
          "git merge-base*" = "allow";
          "git notes get-ref" = "allow";
          "git notes list*" = "allow";
          "git notes show*" = "allow";
          "git reflog show*" = "allow";
          "git submodule -q status*" = "allow";
          "git submodule --quiet status*" = "allow";
          "git submodule status*" = "allow";
          "git worktree list*" = "allow";
          "git check-ignore*" = "allow";
          "gh pr view*" = "allow";
          "gh repo view*" = "allow";
          "gh run list*" = "allow";
          "gh search*" = "allow";
          "command -v*" = "allow";
          "jar tf*" = "allow";
          "mill --version*" = "allow";
          "nix --version*" = "allow";
          "node --version*" = "allow";
          "opencode --version*" = "allow";
          "unzip -l*" = "allow";
          "unzip -p*" = "allow";
          "yarn --version*" = "allow";
        };
        planBash = readOnlyBash // {
          "*" = "ask";
          "git add*" = "deny";
          "git am*" = "deny";
          "git apply*" = "deny";
          "git bisect*" = "deny";
          "git branch *" = "deny";
          "git checkout*" = "deny";
          "git cherry-pick*" = "deny";
          "git clean*" = "deny";
          "git clone*" = "deny";
          "git commit*" = "deny";
          "git config *" = "deny";
          "git fetch*" = "deny";
          "git gc*" = "deny";
          "git init*" = "deny";
          "git ls-remote* --exe*" = "deny";
          "git ls-remote* --u*" = "deny";
          "git ls-remote* -u*" = "deny";
          "git maintenance*" = "deny";
          "git merge" = "deny";
          "git merge *" = "deny";
          "git mv*" = "deny";
          "git notes *" = "deny";
          "git pack-refs*" = "deny";
          "git prune*" = "deny";
          "git pull*" = "deny";
          "git push*" = "deny";
          "git rebase*" = "deny";
          "git reflog *" = "deny";
          "git remote *" = "deny";
          "git repack*" = "deny";
          "git replace *" = "deny";
          "git reset*" = "deny";
          "git restore*" = "deny";
          "git revert*" = "deny";
          "git rm*" = "deny";
          "git sparse-checkout*" = "deny";
          "git stash*" = "deny";
          "git submodule *" = "deny";
          "git switch*" = "deny";
          "git symbolic-ref *" = "deny";
          "git tag *" = "deny";
          "git update-index*" = "deny";
          "git update-ref*" = "deny";
          "git worktree *" = "deny";
        };
        reviewBash = planBash // {
          "mill*test*" = "allow";
          "mill*compile*" = "allow";
          "mill*check*" = "allow";
          "mill*resolve*" = "allow";
          "mill inspect*" = "allow";
          "mill path*" = "allow";
          "bloop test*" = "allow";
          "bloop compile*" = "allow";
          "bloop projects*" = "allow";
          "sbt*test*" = "allow";
          "sbt*compile*" = "allow";
          "sbtn*test*" = "allow";
          "sbtn*compile*" = "allow";
          "node --test*" = "allow";
          "npm run build" = "allow";
          "npm run build -- *" = "allow";
          "yarn build" = "allow";
          "yarn build *" = "allow";
          "nix eval --no-write-lock-file*" = "allow";
          "nix eval*--commit-lock-file*" = "deny";
          "nix eval*--recreate-lock-file*" = "deny";
          "nix eval*--update-input*" = "deny";
          "nix flake check --no-write-lock-file*" = "allow";
          "nix flake check*--commit-lock-file*" = "deny";
          "nix flake check*--recreate-lock-file*" = "deny";
          "nix flake check*--update-input*" = "deny";
          "nix flake metadata --no-write-lock-file*" = "allow";
          "nix flake show --no-write-lock-file*" = "allow";
        };
        reviewAgentSettings = {
          mode = "subagent";
          steps = 100;
          prompt = "{file:${./prompts/review-rules.txt}}";
          permission = {
            edit = "deny";
            bash = reviewBash;
            task = "deny";
          };
        };
        opusReview = "anthropic/claude-opus-5";
        modelSet =
          {
            top,
            review ? top,
            research,
            explore ? research,
            writer,
            small,
            # Compaction is repeated large-input summarization, not reasoning.
            compaction ? research,
          }:
          {
            model = top;
            small_model = small;
            agent = {
              build.model = top;
              plan.model = top;
              review.model = review;
              compaction.model = compaction;
              explore.model = explore;
              scout.model = research;
              test-triage.model = research;
              implement.model = writer;
              scan.model = small;
              title.model = small;
              summary.model = small;
            };
          };
        openaiModels = modelSet {
          top = "openai/gpt-6-astra";
          research = "openai/gpt-5.6-terra";
          explore = "openai/gpt-6-astra";
          writer = "openai/gpt-5.6-sol";
          small = "openai/gpt-5.6-luna";
        };
        anthropicModels = modelSet {
          top = "anthropic/claude-opus-5";
          review = opusReview;
          research = "anthropic/claude-sonnet-5";
          writer = "anthropic/claude-sonnet-5";
          small = "anthropic/claude-haiku-4-5";
        };
        # Default: OpenAI does the work, Opus gives the second opinion on review.
        balancedModels = lib.recursiveUpdate openaiModels {
          agent.review.model = opusReview;
        };
        openaiConfig = builtins.toJSON openaiModels;
        anthropicConfig = builtins.toJSON anthropicModels;
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
        imports = [ inputs.meridian.homeModules.default ];

        services.meridian = {
          enable = true;
          package = meridian;
          settings.pluginConfig = [
            {
              path =
                inputs.meridian.legacyPackages.${pkgs.stdenv.hostPlatform.system}.meridianPlugins.opencode-scrub.path;
            }
          ];
        };

        programs.opencode = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
          settings = {
            inherit (balancedModels) model small_model;
            default_agent = "build";
            subagent_depth = 1;
            compaction = {
              auto = true;
              prune = true;
              reserved = 32000;
              tail_turns = 4;
              preserve_recent_tokens = 12000;
            };
            tool_output = {
              max_lines = 400;
              max_bytes = 24576;
            };
            plugin = [
              foyerSkillsPlugin
              config.services.meridian.opencode.pluginPath
            ];
            permission = {
              external_directory = {
                "*" = "ask";
                "/nix/store/**" = "allow";
                "/tmp/opencode/**" = "allow";
                "~/.cache/JNA/**" = "allow";
                "~/.cache/Tectonic/**" = "allow";
                "~/.cache/bloop/**" = "allow";
                "~/.cache/coursier/**" = "allow";
                "~/.cache/deno/**" = "allow";
                "~/.cache/elixir_make/**" = "allow";
                "~/.cache/goimports/**" = "allow";
                "~/.cache/google-chrome-for-testing/**" = "allow";
                "~/.cache/lua-language-server/**" = "allow";
                "~/.cache/main.kts.compiled.cache/**" = "allow";
                "~/.cache/metals/**" = "allow";
                "~/.cache/mill/**" = "allow";
                "~/.cache/mix/**" = "allow";
                "~/.cache/ms-playwright/**" = "allow";
                "~/.cache/nix-index/**" = "allow";
                "~/.cache/nix/**" = "allow";
                "~/.cache/node-gyp/**" = "allow";
                "~/.cache/org.graalvm.polyglot/**" = "allow";
                "~/.cache/rustler_precompiled/**" = "allow";
                "~/.cache/scalacli/**" = "allow";
                "~/.cache/scalablytyped/**" = "allow";
                "~/.cache/tree-sitter/**" = "allow";
                "~/.cache/typescript/**" = "allow";
                "~/.cache/uv/**" = "allow";
                "~/.cache/yarn/**" = "allow";
                "~/.config/opencode/**" = "allow";
                "~/.ivy2/**" = "allow";
                "~/.local/share/opencode/log/**" = "allow";
                "~/.m2/**" = "allow";
                "~/Projects/**" = "allow";
              };

              bash = {
                "*" = "allow";

                "curl*-X DELETE*" = "ask";
                "curl*-X PATCH*" = "ask";
                "curl*-X POST*" = "ask";
                "curl*-X PUT*" = "ask";
                "curl*-XDELETE*" = "ask";
                "curl*-XPATCH*" = "ask";
                "curl*-XPOST*" = "ask";
                "curl*-XPUT*" = "ask";
                "curl*-F*" = "ask";
                "curl*-T*" = "ask";
                "curl*-d*" = "ask";
                "curl*--data*" = "ask";
                "curl*--form*" = "ask";
                "curl*--json*" = "ask";
                "curl*--request DELETE*" = "ask";
                "curl*--request PATCH*" = "ask";
                "curl*--request POST*" = "ask";
                "curl*--request PUT*" = "ask";
                "curl*--request=DELETE*" = "ask";
                "curl*--request=PATCH*" = "ask";
                "curl*--request=POST*" = "ask";
                "curl*--request=PUT*" = "ask";
                "curl*--upload-file*" = "ask";
                "deploy *" = "ask";
                "gh *" = "ask";
                "gh --version*" = "allow";
                "gh api*" = "ask";
                "gh auth status*" = "allow";
                "gh issue list*" = "allow";
                "gh issue status*" = "allow";
                "gh issue view*" = "allow";
                "gh pr checks*" = "allow";
                "gh pr diff*" = "allow";
                "gh pr list*" = "allow";
                "gh pr status*" = "allow";
                "gh pr view*" = "allow";
                "gh release list*" = "allow";
                "gh release view*" = "allow";
                "gh repo list*" = "allow";
                "gh repo view*" = "allow";
                "gh run list*" = "allow";
                "gh run view*" = "allow";
                "gh search*" = "allow";
                "gh workflow list*" = "allow";
                "gh workflow view*" = "allow";
                "git checkout --*" = "ask";
                "git clean*" = "ask";
                "git push*" = "ask";
                "git rebase*" = "ask";
                "git reset*" = "ask";
                "git restore*" = "ask";
                "kill *" = "ask";
                "nix profile*" = "ask";
                "nix-env*" = "ask";
                "nixos-rebuild*" = "ask";
                "npm publish*" = "ask";
                "pkill*" = "ask";
                "rm *" = "ask";
                "sops *" = "ask";
                "ssh *" = "ask";
                "sudo*" = "ask";
                "systemctl*" = "ask";
              };

              edit = {
                "*" = "allow";
                "/nix/store/**" = "deny";
                "/run/current-system/**" = "deny";
                "/nix/var/nix/profiles/system/**" = "deny";
                "/etc/static/**" = "deny";
              };

              skill = {
                "*" = "allow";
              };

              playwright_browser_run_code_unsafe = "ask";
              "grafana-production_alerting_manage_routing" = "ask";
              "grafana-production_alerting_manage_rules" = "ask";
              "grafana-staging_alerting_manage_routing" = "ask";
              "grafana-staging_alerting_manage_rules" = "ask";
            };
            provider = {
              anthropic.options = {
                apiKey = "x";
                baseURL = "http://127.0.0.1:3456";
              };
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
            agent = lib.recursiveUpdate {
              build = {
                color = "secondary";
                description = "Primary implementation agent and orchestrator for coding work.";
                mode = "primary";
                permission.task = {
                  "*" = "deny";
                  explore = "allow";
                  scout = "allow";
                  test-triage = "allow";
                  scan = "allow";
                  review = "allow";
                  review-sol = "allow";
                  implement = "allow";
                };
              };
              plan = {
                color = "primary";
                description = "Read-only planning and architectural analysis.";
                mode = "primary";
                permission = {
                  edit = "deny";
                  bash = planBash;
                  task = {
                    "*" = "deny";
                    explore = "allow";
                    scout = "allow";
                    test-triage = "allow";
                    scan = "allow";
                    review = "allow";
                    review-sol = "allow";
                  };
                };
              };
              explore = {
                description = ''Read-only codebase exploration and reasoning. Use proactively to understand behavior, trace interactions, or synthesize findings across files. Use scan instead for bounded lookups and mechanical inventories. Specify thoroughness: "quick" for focused questions, "medium" for moderate exploration, or "very thorough" for comprehensive analysis. Returns concise evidence with file and line references; never edits.'';
                mode = "subagent";
                steps = 100;
                permission = {
                  edit = "deny";
                  bash = readOnlyBash;
                  task = "deny";
                };
              };
              scout = {
                description = "Read-only dependency and external documentation research. Use proactively before adopting or upgrading a library, when you need a package's actual API surface, or when a question is answered by upstream docs, changelogs, or dependency source rather than by this repository. Returns the answer with its exact source and any version caveats.";
                mode = "subagent";
                steps = 100;
                prompt = "{file:${./prompts/scout-rules.txt}}";
                permission = {
                  edit = "deny";
                  bash = readOnlyBash;
                  task = "deny";
                };
              };
              test-triage = {
                description = "Reproduces and analyzes test or build failures without modifying source. Use proactively whenever a test suite, compile, or check fails and the root cause is not already obvious. Returns the failing command, the first causal error, likely ownership, and the smallest next diagnostic.";
                mode = "subagent";
                steps = 100;
                prompt = "{file:${./prompts/test-triage-rules.txt}}";
                permission = {
                  edit = "deny";
                  bash = reviewBash;
                  task = "deny";
                };
              };
              scan = {
                description = "Performs narrow mechanical searches, inventories, and consistency checks. Use proactively for counting occurrences, listing every call site, or verifying that a pattern holds repo-wide. Returns terse counts, paths, and line references; no bash, no edits.";
                mode = "subagent";
                steps = 100;
                prompt = "{file:${./prompts/scan-rules.txt}}";
                permission = {
                  edit = "deny";
                  bash = "deny";
                  task = "deny";
                };
              };
              review = reviewAgentSettings // {
                description = "Reviews changes for defects, regressions, risks, and missing tests without editing. Use proactively after completing a non-trivial change and before committing. Returns findings ordered by severity with file and line references.";
                disable = false;
              };
              review-sol = reviewAgentSettings // {
                description = "Fallback reviewer for an explicitly exhausted Claude subscription quota. Reviews the same scope for defects, regressions, risks, and missing tests without editing.";
                model = "openai/gpt-5.6-sol";
              };
              implement = {
                description = "Implements one explicitly bounded, disjoint file scope assigned by the primary agent. Use proactively to parallelize independent edits once you can name each agent's exact file ownership up front. Does not commit, push, or delegate.";
                mode = "subagent";
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
            } balancedModels.agent;
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
                  "--isolated"
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
              sonar-foyer = {
                type = "local";
                command = [ "${sonarMcp}/bin/mcp-sonar-foyer" ];
                environment = {
                  SONARQUBE_URL = "https://sonarqube.foyer.lu/";
                  TELEMETRY_DISABLED = "true";
                };
                enabled = false;
                timeout = 60000;
              };
            };
          };
        };
        programs.zsh.shellAliases = {
          oc = "opencode --auto";
          oc-openai = "OPENCODE_CONFIG_CONTENT=${lib.escapeShellArg openaiConfig} opencode --auto";
          oc-anthropic = "OPENCODE_CONFIG_CONTENT=${lib.escapeShellArg anthropicConfig} opencode --auto";
          oc-foyer = "OPENCODE_CONFIG_CONTENT=${lib.escapeShellArg foyerConfig} opencode --auto";
          oc-power = "OPENCODE_CONFIG_CONTENT=${lib.escapeShellArg superpowersConfig} opencode --auto";
        };
        programs.zsh.initContent = lib.mkAfter ''
          wait_for_metals_mcp() {
            local config http_status url
            local -i deadline

            [[ -f opencode.json || -f opencode.jsonc ]] || return 0
            config="$(${pkgs.coreutils}/bin/timeout --kill-after=1s 10s opencode debug config 2>/dev/null)" || return 0
            url="$(${lib.getExe pkgs.jq} -r '
              .mcp["metals-lsp"]
              | select(.type == "remote" and .enabled != false)
              | .url // empty
            ' <<<"$config" 2>/dev/null)" || return 0
            [[ "$url" == http://localhost:* || "$url" == http://127.0.0.1:* ]] || return 0

            deadline=$(( SECONDS + 60 ))
            while (( SECONDS < deadline )); do
              http_status="$(${lib.getExe pkgs.curl} \
                --silent \
                --output /dev/null \
                --write-out '%{http_code}' \
                --connect-timeout 1 \
                --max-time 1 \
                "$url")" || http_status=
              if [[ "$http_status" == [234][0-9][0-9] ]]; then
                return 0
              fi
              sleep 0.25
            done

            print -u2 -- "Timed out waiting for Metals MCP at $url; starting OpenCode anyway"
          }

          opencode() {
            local arg restore_session=false has_auto=false herdr_agent=false

            for arg in "$@"; do
              case "$arg" in
                --session|--session=*)
                  restore_session=true
                  herdr_agent=true
                  ;;
                --port|--port=*) herdr_agent=true ;;
                --auto) has_auto=true ;;
              esac
            done

            if [[ "''${HERDR_ENV:-}" == 1 && "$herdr_agent" == true ]]; then
              wait_for_metals_mcp
            fi

            if [[ "$restore_session" == true && "$has_auto" == false ]]; then
              command opencode --auto "$@"
              return
            fi
            command opencode "$@"
          }
        '';
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
          - For bugs, reproduce first and identify the root cause before changing code; add a failing regression test, then fix.
          - Log important branches with enough context (e.g., request/correlation IDs) for production debugging.

          ## Commits
          - Use Conventional Commits
          - Before any commit, try to run the project formatter and linter on changed files.

          ## Filesystem
          - Search known dependency caches directly; never glob or search all of `~/.cache`.

          ## Delegation
          - This file explicitly instructs you to use the Task tool. Delegating is the expected default, not an exception.
          - Delegate proactively, without being asked:
            - understanding codebase behavior, tracing interactions, or synthesizing findings across files -> explore
            - dependency, library, or external documentation research -> scout
            - failing tests or build errors you have not yet diagnosed -> test-triage
            - bounded lookups ("where is X"), inventories, counts, and mechanical consistency checks across many files -> scan
            - defect review of a completed change -> review
            - bounded implementation work in a file scope you can name up front -> implement
          - If a scan lookup is inconclusive or requires tracing behavior, delegate the follow-up to explore.
          - Handle work inline only for a specific known file path, a 2-3 file read, or a single edit.
          - Delegate only bounded, independent work with an explicit expected report.
          - For defect reviews, the primary agent must first call review.
          - Only when review returns an explicit Claude subscription quota exhausted error, inform the user and rerun the exact same review scope as a fresh review-sol task. Do not continue the Opus task with task_id.
          - Do not fall back for generic errors or transient rate limits. If review-sol fails, report the blocker; do not retry or enter another fallback loop.
          - Concurrent writer agents may share a worktree only when assigned disjoint files or directories.
          - Give every writer exact ownership boundaries. Stop and ask if scopes overlap or unexpected edits appear.
          - The primary agent reviews and integrates writer results. Subagents do not commit, push, or delegate further.
          - Subagents return concise findings, changed files, verification, and unresolved risks instead of raw output.

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
          claudeCode
          meridian
          metals
        ];
      };
  };
}
