# MCP servers OpenCode and pi share, in the mcpServers shape of pi's mcp.json:
# `command`, `args`, and `env` for stdio servers, `url` for remote ones,
# `enabled`, and `timeout` in seconds.
{ lib, pkgs }:

let
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
  odooMcp = pkgs.writeShellApplication {
    name = "mcp-odoo-froidmont";
    runtimeInputs = [
      pkgs.libsecret
      pkgs.python3
      pkgs.uv
    ];
    text = ''
      if ! odooApiKey="$(secret-tool lookup application opencode service froidmont-solutions-srl.odoo.com)"; then
        echo "Unable to retrieve the Odoo API key from Secret Service" >&2
        exit 1
      fi

      if [[ -z "$odooApiKey" ]]; then
        echo "The Odoo API key retrieved from Secret Service is empty" >&2
        exit 1
      fi

      export ODOO_API_KEY="$odooApiKey"
      exec uvx --python ${lib.getExe pkgs.python3} --no-python-downloads mcp-server-odoo==0.8.0
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
in
{
  dstudiodoc = {
    url = "http://iavideotranslation.lefoyer.lu:7860/mcp/";
    enabled = false;
    timeout = 10;
  };
  chrome-devtools = {
    command = "${pkgs.nodejs}/bin/npx";
    args = [
      "-y"
      "chrome-devtools-mcp@latest"
      "--executable-path=${lib.getExe pkgs.ungoogled-chromium}"
    ];
    enabled = false;
    timeout = 60;
  };
  playwright = {
    command = "${pkgs.nodejs}/bin/npx";
    args = [
      "-y"
      "@playwright/mcp@0.0.79"
      "--executable-path=${lib.getExe pkgs.ungoogled-chromium}"
      "--isolated"
    ];
    enabled = true;
    timeout = 60;
  };
  jira = {
    command = "${jiraMcp}/bin/mcp-atlassian-jira";
    env = {
      JIRA_URL = "https://jira.foyer.lu/";
      TOOLSETS = lib.concatStringsSep "," jiraToolsets;
    };
    enabled = false;
    timeout = 60;
  };
  sonar-foyer = {
    command = "${sonarMcp}/bin/mcp-sonar-foyer";
    env = {
      SONARQUBE_URL = "https://sonarqube.foyer.lu/";
      TELEMETRY_DISABLED = "true";
    };
    enabled = false;
    timeout = 60;
  };
  odoo = {
    command = "${odooMcp}/bin/mcp-odoo-froidmont";
    env = {
      ODOO_URL = "https://froidmont-solutions-srl.odoo.com";
      ODOO_DB = "froidmont-solutions-srl";
      ODOO_USER = "paul-henri@froidmont.solutions";
      # Odoo Online can't install the server's module, so writes need full YOLO mode.
      ODOO_YOLO = "true";
      ODOO_MCP_ENABLE_METHOD_CALLS = "true";
    };
    enabled = false;
    timeout = 60;
  };
  stripe = {
    url = "https://mcp.stripe.com";
    enabled = false;
  };
}
