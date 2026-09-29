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
        opusReview = "anthropic/claude-opus-5-5";
        fableReview = "anthropic/claude-fable-5-1";
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
          research = "openai/gpt-6-sol";
          explore = "openai/gpt-6-astra";
          writer = "openai/gpt-6-sol";
          small = "openai/gpt-6-luna";
        };
        anthropicModels = modelSet {
          top = "anthropic/claude-opus-5-5";
          review = opusReview;
          research = "anthropic/claude-sonnet-5";
          writer = "anthropic/claude-sonnet-5";
          small = "anthropic/claude-haiku-4-5";
        };
        # Default: OpenAI does the work, Opus gives the second opinion on review.
        balancedModels = lib.recursiveUpdate openaiModels {
          agent.review.model = opusReview;
        };
        premiumModels =
          lib.recursiveUpdate
            (modelSet {
              top = "openai/gpt-6-astra";
              review = opusReview;
              research = "openai/gpt-6-astra";
              writer = "openai/gpt-6-astra";
              small = "openai/gpt-6-astra";
            })
            {
              agent = {
                build.variant = "xhigh";
                plan.variant = "xhigh";
                implement.variant = "xhigh";
                explore.variant = "xhigh";
                test-triage.variant = "xhigh";
                review-sol = {
                  model = "openai/gpt-6-astra";
                  variant = "xhigh";
                };
              };
            };
        customOverlay = {
          subagent_depth = 1;
          instructions = [ "${./prompts/delegation-rules.md}" ];
          agent = lib.recursiveUpdate {
            build = {
              description = "Primary implementation agent and orchestrator for coding work.";
              mode = "primary";
              permission.task = {
                "*" = "deny";
                explore = "allow";
                scout = "allow";
                test-triage = "allow";
                scan = "allow";
                review = "allow";
                review-fable = "allow";
                review-opus = "allow";
                review-sol = "allow";
                implement = "allow";
              };
            };
            plan = {
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
                  review-fable = "allow";
                  review-opus = "allow";
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
            review-fable = reviewAgentSettings // {
              description = "Reviews changes with Fable when explicitly requested, regardless of the session's default reviewer. Returns defects, regressions, risks, and missing tests ordered by severity with file and line references; never edits.";
              model = fableReview;
            };
            review-opus = reviewAgentSettings // {
              description = "Reviews changes with Opus when explicitly requested, regardless of the session's default reviewer. Returns defects, regressions, risks, and missing tests ordered by severity with file and line references; never edits.";
              model = opusReview;
            };
            review-sol = reviewAgentSettings // {
              description = "Fallback reviewer for an explicitly exhausted Claude subscription quota. Reviews the same scope for defects, regressions, risks, and missing tests without editing.";
              model = "openai/gpt-6-sol";
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
        };
        presets = pkgs.writeText "oc-presets.json" (
          builtins.toJSON {
            custom = customOverlay;
            profiles = {
              balanced = balancedModels;
              openai = openaiModels;
              premium = premiumModels;
              anthropic = anthropicModels;
            };
            power.plugin = [ "superpowers@git+https://github.com/obra/superpowers.git#v6.0.3" ];
            reviewModels = {
              fable = fableReview;
              opus = opusReview;
            };
          }
        );
        oc = pkgs.writeShellApplication {
          name = "oc";
          text = ''
            readonly native=${lib.escapeShellArg (lib.getExe config.programs.opencode.package)}
            readonly presets=${lib.escapeShellArg (toString presets)}
            readonly jq=${lib.getExe pkgs.jq}
            readonly curl=${lib.getExe pkgs.curl}
            readonly timeout=${pkgs.coreutils}/bin/timeout
            readonly sleep=${pkgs.coreutils}/bin/sleep
          ''
          + builtins.readFile ./oc.sh;
          derivationArgs = {
            passthru.presets = presets;
            # writeShellApplication uses writeTextFile, which has no install phase.
            postCheck = ''
              install -Dm644 ${./oc.zsh} "$out/share/zsh/site-functions/_oc"
            '';
          };
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
            agent = {
              build.color = "secondary";
              plan = {
                color = "primary";
                permission = {
                  edit = "deny";
                  bash = planBash;
                };
              };
              inherit (balancedModels.agent) compaction title summary;
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
        # Herdr restores agents using fixed `opencode --session ...` argv.
        # Route that path through the launcher too; ordinary native calls stay native.
        programs.zsh.initContent = lib.mkAfter ''
          opencode() {
            if [[ "''${HERDR_ENV:-}" == 1 && "''${1:-}" == --session ]]; then
              ${lib.getExe oc} "$@"
            else
              command opencode "$@"
            fi
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

        '';
        xdg.configFile."opencode/skills/scalive/SKILL.md".source = ./skills/scalive/SKILL.md;
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
          oc
          claudeCode
          meridian
          metals
        ];
      };
  };
}
