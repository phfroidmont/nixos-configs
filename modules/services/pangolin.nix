{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.pangolin;
in
{
  options.modules.services.pangolin = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
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
      home.file.".config/pangolin/config.json".text = builtins.toJSON {
        up = {
          override_dns = true;
          tunnel_dns = true;
          # Pangolin's virtual IP for dns.internal; recheck if the resource is recreated.
          upstream_dns = [ "100.96.128.11:53" ];
          match_domains_dns = [
            "foyer.cloud"
            "*.foyer.cloud"
            "foyer.lu"
            "*.foyer.lu"
            "lefoyer.lu"
            "*.lefoyer.lu"
            "*.internal"
            "*.banditlair.com"
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
      pangolin-cli
    ];
  };
}
