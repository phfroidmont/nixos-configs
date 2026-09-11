{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.work-proxy;
  mongodbCompass = pkgs.symlinkJoin {
    name = "mongodb-compass-${pkgs.mongodb-compass.version}";
    paths = [ pkgs.mongodb-compass ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/mongodb-compass"
      makeWrapper ${lib.getExe pkgs.mongodb-compass} "$out/bin/mongodb-compass" \
        --add-flags "--ignore-additional-command-line-flags" \
        --add-flags "--password-store=gnome-libsecret"
    '';
  };
in
{
  options.modules.services.work-proxy = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    services.tinyproxy = {
      enable = true;
      settings = {
        LogLevel = "Info";
        Port = 2345;
        Upstream = [
          ''upstream http foyer-wsl.internal:2345 ".microsoftonline.com"''
        ];
      };
    };

    security.pki.certificateFiles = [
      ./certs/Foyer-Group-Root-CA.crt
      ./certs/Foyer-Sub-CA.crt
    ];

    environment.variables = {
      NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";
      JAVAX_NET_SSL_TRUSTSTORE = ./certs/cacerts;
      JAVA_OPTS = "-Djavax.net.ssl.trustStore=${./certs/cacerts} -Djavax.net.ssl.trustStorePassword=changeit";
      JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStore=${./certs/cacerts} -Djavax.net.ssl.trustStorePassword=changeit";
    };

    systemd.services.pangolin = {
      description = "Pangolin work tunnel";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "${
        config.users.users.${config.user.name}.home
      }/.config/pangolin/accounts.json";
      path = [ pkgs.openresolv ];
      environment.HOME = "/var/lib/pangolin";
      environment.PANGOLIN_CLI_DISABLE_UPDATE_CHECK = "true";
      serviceConfig = {
        StateDirectory = "pangolin";
        StateDirectoryMode = "0700";
        # Keep root's config immutable and import only the user's login credentials.
        LoadCredential = "accounts.json:${
          config.users.users.${config.user.name}.home
        }/.config/pangolin/accounts.json";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -D -m 0600 %d/accounts.json /var/lib/pangolin/.config/pangolin/accounts.json"
          "${pkgs.coreutils}/bin/install -D -m 0600 ${
            pkgs.writeText "pangolin-config.json"
              config.home-manager.users.${config.user.name}.home.file.".config/pangolin/config.json".text
          } /var/lib/pangolin/.config/pangolin/config.json"
        ];
        ExecStart = "${lib.getExe pkgs.pangolin-cli} up --attach";
        Restart = "always";
        # Let the DNS watchdog survive and finish its 15-second recovery before restarting.
        KillMode = "process";
        RestartSec = 20;
        RestartSteps = 5;
        RestartMaxDelaySec = "5min";
      };
    };

    security.sudo.extraRules = [
      {
        users = [ config.user.name ];
        runAs = "root";
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl start pangolin.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl stop pangolin.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    home-manager.users.${config.user.name} = {
      home.file.".sbt/repositories".text = ''
        [repositories]
          local
          maven-local
          nexus-maven: https://nexus.foyer.lu/repository/mvn-all/
          nexus-ivy: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext]
          nexus-ivy-sbt: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[artifact](-[classifier])-[type].[ext]
      '';

      home.file.".config/pangolin/config.json".text = builtins.toJSON {
        up = {
          override_dns = true;
          tunnel_dns = true;
          upstream_dns = [ "10.33.0.100" ];
          match_domains_dns = [
            "foyer.cloud"
            "*.foyer.cloud"
            "foyer.lu"
            "*.foyer.lu"
            "lefoyer.lu"
            "*.lefoyer.lu"
            "*.internal"
            "uptime.banditlair.com"
          ];
        };
      };

      systemd.user.services.pangolin = {
        Unit = {
          Description = "Start the Pangolin work tunnel with the desktop session";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "/run/wrappers/bin/sudo -n ${pkgs.systemd}/bin/systemctl start pangolin.service";
          ExecStop = "/run/wrappers/bin/sudo -n ${pkgs.systemd}/bin/systemctl stop pangolin.service";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    environment.systemPackages = with pkgs; [
      (sbt.override { jre = jdk17; })
      mongodbCompass
      chisel
      get-token
      mia
      jira-cli-go
      pangolin-cli
    ];
  };
}
