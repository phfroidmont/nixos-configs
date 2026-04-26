{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.hermesAccounting;
  repoParent = builtins.dirOf cfg.repoPath;
  pySitePackages = "lib/python3.11/site-packages";

  asyncpgPy = pkgs.python311Packages.buildPythonPackage rec {
    pname = "asyncpg";
    version = "0.31.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-yYk4bIOUC/vXhxgPKxUZQV4tPWJ3pw2dDwFFrHNQBzU=";
    };

    build-system = with pkgs.python311Packages; [
      cython
      setuptools
    ];

    nativeBuildInputs = [ pkgs.libpq ];
    doCheck = false;
    pythonImportsCheck = [ "asyncpg" ];
  };

  aiosqlitePy = pkgs.python311Packages.buildPythonPackage rec {
    pname = "aiosqlite";
    version = "0.21.0";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "omnilib";
      repo = "aiosqlite";
      tag = "v${version}";
      hash = "sha256-3l/uR97WuLlkAEdogL9iYoXp89bsAcpH6XEtMELsX9o=";
    };

    build-system = [ pkgs.python311Packages.flit-core ];
    dependencies = [ pkgs.python311Packages.typing-extensions ];
    doCheck = false;
    pythonImportsCheck = [ "aiosqlite" ];
  };

  matrixPythonPath = lib.concatStringsSep ":" [
    "${asyncpgPy}/${pySitePackages}"
    "${aiosqlitePy}/${pySitePackages}"
  ];

  baseHermesPackage = inputs."hermes-agent".packages.${pkgs.system}.default;
  hermesWithMatrixDeps = pkgs.symlinkJoin {
    name = "hermes-agent-with-matrix-deps";
    paths = [ baseHermesPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/hermes" --prefix PYTHONPATH : "${matrixPythonPath}"
      wrapProgram "$out/bin/hermes-agent" --prefix PYTHONPATH : "${matrixPythonPath}"
      wrapProgram "$out/bin/hermes-acp" --prefix PYTHONPATH : "${matrixPythonPath}"
    '';
  };

  gitGate = pkgs.writeShellScriptBin "hermes-accounting-git-gate" ''
    #!/usr/bin/env bash
    set -euo pipefail

    MODE="safe"
    REASONS=()

    if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "MODE=review"
      echo "REASON=not-a-git-repo"
      exit 0
    fi

    if ! ${pkgs.git}/bin/git diff --quiet --; then
      MODE="review"
      REASONS+=("unstaged-changes-present")
    fi

    if ${pkgs.git}/bin/git diff --cached --quiet --; then
      MODE="review"
      REASONS+=("no-staged-changes")
    fi

    if ! ${pkgs.hledger}/bin/hledger check >/dev/null 2>&1; then
      MODE="review"
      REASONS+=("hledger-check-failed")
    fi

    ADDED=0
    DELETED=0
    STATUS_LINES="$(${pkgs.git}/bin/git diff --cached --name-status)"
    NUMSTAT_LINES="$(${pkgs.git}/bin/git diff --cached --numstat)"

    while IFS=$'\t' read -r a d _rest; do
      [ -z "''${a:-}" ] && continue
      [ "$a" = "-" ] && a=0
      [ "$d" = "-" ] && d=0
      ADDED=$((ADDED + a))
      DELETED=$((DELETED + d))
    done <<< "$NUMSTAT_LINES"

    TOTAL=$((ADDED + DELETED))

    if [ "$TOTAL" -gt ${toString cfg.git.maxChangedLines} ]; then
      MODE="review"
      REASONS+=("changed-lines-exceed-${toString cfg.git.maxChangedLines}")
    fi

    if [ "$DELETED" -gt 0 ]; then
      MODE="review"
      REASONS+=("contains-deletions")
    fi

    while IFS=$'\t' read -r status _path; do
      [ -z "''${status:-}" ] && continue
      case "$status" in
        D*|R*|C*)
          MODE="review"
          REASONS+=("contains-''${status}-changes")
          ;;
      esac
    done <<< "$STATUS_LINES"

    if [ "''${#REASONS[@]}" -eq 0 ]; then
      REASONS=("none")
    fi

    echo "MODE=$MODE"
    echo "ADDED_LINES=$ADDED"
    echo "DELETED_LINES=$DELETED"
    echo "TOTAL_LINES=$TOTAL"
    echo "REASONS=$(IFS=,; echo "''${REASONS[*]}")"
  '';

  soulText = ''
    You are hermes-accounting, a careful personal accounting assistant.

    Never fabricate transactions. If required fields are missing, ask for clarification.
    Use double-entry bookkeeping and keep the hledger journal valid.
    Always write transactions in chronological order (oldest to newest) in the journal.
    Before writing, show the parsed transaction and ask for confirmation when ambiguity exists.

    For every accounting update, follow this workflow exactly:
    1. Parse the user transaction into clear debit/credit postings and show it back.
    2. Ask for confirmation only if there is ambiguity or missing data.
    3. Apply the journal/import change in git working tree.
    3b. After adding a transaction, compute and report the updated total of the affected account(s) using hledger.
    4. Stage changes with: git add -A
    5. Run: hermes-accounting-git-gate
    6. If MODE=safe:
       - commit with a concise accounting-focused message
       - push directly to origin ${cfg.git.branch}
       - send a Matrix confirmation including commit hash, changed files, and the updated hledger total for the affected account(s)
    7. If MODE=review:
       - create branch hermes/review-YYYYMMDD-HHMMSS
       - commit and push that branch
       - send a Matrix message including reasons from REASONS, exact merge instructions, and the updated hledger total for the affected account(s)

    Never force push. Never rewrite git history.
  '';

  soulFile = pkgs.writeText "hermes-accounting-SOUL.md" soulText;
in
{
  options.modules.services.hermesAccounting = {
    enable = lib.my.mkBoolOpt false;
    repoPath = lib.my.mkOpt lib.types.str "/var/lib/hermes-accounting/workspace/pta";
    # envFile = lib.my.mkOpt lib.types.str "/var/lib/hermes-accounting/env";
    git = {
      remoteUrl = lib.my.mkOpt (lib.types.nullOr lib.types.str) null;
      branch = lib.my.mkOpt lib.types.str "main";
      forgejoHost = lib.my.mkOpt (lib.types.nullOr lib.types.str) null;
      maxChangedLines = lib.my.mkOpt lib.types.int 20;
      bootstrapMode = lib.my.mkOpt (lib.types.enum [
        "clone-only"
        "sync-on-start"
      ]) "sync-on-start";
    };
  };

  config = lib.mkIf cfg.enable {
    services."hermes-agent" = {
      enable = true;
      package = hermesWithMatrixDeps;
      user = "hermes-accounting";
      group = "hermes-accounting";
      stateDir = "/var/lib/hermes-accounting";
      workingDirectory = cfg.repoPath;
      # environmentFiles = [ cfg.envFile ];
      addToSystemPackages = true;

      settings = {
        model = {
          provider = "openai-codex";
          default = "gpt-5.5";
        };
        toolsets = [ "all" ];
        terminal = {
          backend = "local";
          cwd = cfg.repoPath;
          timeout = 300;
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
        };
        matrix = {
          require_mention = true;
          auto_thread = true;
          dm_mention_threads = false;
        };
        group_sessions_per_user = true;
      };

      extraPackages = with pkgs; [
        git
        hledger
        curl
        jq
        gitGate
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${repoParent} 0750 hermes-accounting hermes-accounting -"
    ];

    system.activationScripts."hermes-accounting-soul" = lib.stringAfter [ "hermes-agent-setup" ] ''
      install -o hermes-accounting -g hermes-accounting -m 0640 -D ${soulFile} /var/lib/hermes-accounting/.hermes/SOUL.md
    '';

    systemd.services.hermes-accounting-git-bootstrap = {
      description = "Bootstrap Hermes accounting git workspace";
      wantedBy = [ "hermes-agent.service" ];
      before = [ "hermes-agent.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes-accounting";
        Group = "hermes-accounting";
        UMask = "0077";
      };
      script = ''
        set -eu

        HOME_DIR="/var/lib/hermes-accounting"
        SSH_DIR="$HOME_DIR/.ssh"
        KEY_PATH="$SSH_DIR/id_ed25519"
        KNOWN_HOSTS_PATH="$SSH_DIR/known_hosts"
        REPO_PATH="${cfg.repoPath}"
        REPO_PARENT="${repoParent}"
        BRANCH="${cfg.git.branch}"
        REMOTE_URL="${if cfg.git.remoteUrl == null then "" else cfg.git.remoteUrl}"
        FORGEJO_HOST="${if cfg.git.forgejoHost == null then "" else cfg.git.forgejoHost}"
        BOOTSTRAP_MODE="${cfg.git.bootstrapMode}"

        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"

        if [ ! -f "$KEY_PATH" ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f "$KEY_PATH" -C "hermes-accounting@local"
        fi

        touch "$KNOWN_HOSTS_PATH"
        chmod 600 "$KNOWN_HOSTS_PATH"

        if [ -n "$FORGEJO_HOST" ]; then
          if ! ${pkgs.openssh}/bin/ssh-keygen -F "$FORGEJO_HOST" -f "$KNOWN_HOSTS_PATH" >/dev/null 2>&1; then
            ${pkgs.openssh}/bin/ssh-keyscan -H "$FORGEJO_HOST" >> "$KNOWN_HOSTS_PATH"
          fi
        fi

        if [ -z "$REMOTE_URL" ]; then
          exit 0
        fi

        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i $KEY_PATH -o UserKnownHostsFile=$KNOWN_HOSTS_PATH -o StrictHostKeyChecking=yes"

        mkdir -p "$REPO_PARENT"

        if [ ! -d "$REPO_PATH/.git" ]; then
          ${pkgs.git}/bin/git clone --branch "$BRANCH" "$REMOTE_URL" "$REPO_PATH"
        elif [ "$BOOTSTRAP_MODE" = "sync-on-start" ]; then
          ${pkgs.git}/bin/git -C "$REPO_PATH" fetch --all --prune
          ${pkgs.git}/bin/git -C "$REPO_PATH" checkout "$BRANCH"
          ${pkgs.git}/bin/git -C "$REPO_PATH" pull --ff-only origin "$BRANCH"
        fi

        ${pkgs.git}/bin/git -C "$REPO_PATH" config user.name "hermes-accounting"
        ${pkgs.git}/bin/git -C "$REPO_PATH" config user.email "hermes-accounting@local"
      '';
    };

    systemd.services.hermes-agent = {
      requires = [ "hermes-accounting-git-bootstrap.service" ];
      after = [ "hermes-accounting-git-bootstrap.service" ];
    };
  };
}
