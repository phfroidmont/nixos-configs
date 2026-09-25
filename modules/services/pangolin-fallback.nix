{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.pangolin-fallback;
  interface = "pg-fallback";
  wgService = "wg-quick-${interface}";
  wgUnit = "${wgService}.service";
  wstunnelUnit = "wstunnel-pangolin-fallback.service";
  routing = pkgs.writeShellScript "pangolin-fallback-routing" ''
    export IP=${lib.getExe' pkgs.iproute2 "ip"}
    export RELAY_IPV4=${lib.escapeShellArg cfg.relayIPv4}
    exec ${pkgs.bash}/bin/bash ${./pangolin-fallback-routing.sh} "$@"
  '';
  controller = pkgs.writeShellScript "pangolin-fallback-reconcile" ''
    export SYSTEMCTL=${lib.getExe' pkgs.systemd "systemctl"}
    export BUSCTL=${lib.getExe' pkgs.systemd "busctl"}
    export CURL=${lib.getExe pkgs.curl}
    export ROUTING=${routing}
    export KEY_FILE=${lib.escapeShellArg cfg.privateKeyFile}
    export WG_UNIT=${lib.escapeShellArg wgUnit}
    export WSTUNNEL_UNIT=${lib.escapeShellArg wstunnelUnit}
    exec ${pkgs.bash}/bin/bash ${./pangolin-fallback.sh} ${lib.escapeShellArgs cfg.connectionUUIDs}
  '';
in
{
  options.modules.services.pangolin-fallback = {
    enable = lib.mkEnableOption "the Pangolin WireGuard-over-WebSocket fallback";

    connectionUUIDs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "NetworkManager primary connection UUIDs on which to enable the fallback.";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secrets/wg-stellaris-fallback.key";
      description = "Runtime path to the fallback WireGuard private key.";
    };

    relayIPv4 = lib.mkOption {
      type = lib.types.str;
      default = "195.201.112.227";
      description = "Literal IPv4 address of the WebSocket relay.";
    };

    relayHost = lib.mkOption {
      type = lib.types.str;
      default = "ws.banditlair.com";
      description = "TLS SNI and HTTP Host name of the WebSocket relay.";
    };

    relayPublicKey = lib.mkOption {
      type = lib.types.str;
      default = "ycPnsgWTOgJzPTWi0y9BOLZQ8lwwGlpkp3i/QTjBXRk=";
      description = "WireGuard public key of the relay.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl."net.ipv4.conf.all.src_valid_mark" = 1;

    networking.firewall =
      let
        relayReply = "! -i ${interface} -s ${lib.escapeShellArg cfg.relayIPv4} -p tcp --sport 443 -m addrtype --dst-type LOCAL -j MARK --set-mark 51871";
      in
      {
        # Raw PREROUTING runs before NixOS's mangle-table rpfilter check.
        extraCommands = ''
          iptables -t raw -C PREROUTING ${relayReply} 2>/dev/null || iptables -t raw -I PREROUTING 1 ${relayReply}
        '';
        extraStopCommands = ''
          iptables -t raw -D PREROUTING ${relayReply} 2>/dev/null || true
        '';
      };

    assertions = [
      {
        assertion = config.modules.services.pangolin.enable && config.networking.networkmanager.enable;
        message = "Pangolin fallback requires Pangolin and NetworkManager.";
      }
      {
        assertion = config.networking.networkmanager.dns == "default";
        message = "Pangolin fallback expects native resolvers in NetworkManager's default DNS mode.";
      }
    ];

    networking.wg-quick.interfaces.${interface} = {
      autostart = false;
      address = [ "10.250.251.2/32" ];
      mtu = 1280;
      inherit (cfg) privateKeyFile;
      # Do not capture normal traffic before the controller proves egress works.
      table = "off";
      postUp = "${routing} setup";
      # Even if rule removal fails, deleting the interface removes its route.
      preDown = "${routing} cleanup || true";
      extraOptions.FwMark = 51871;
      peers = [
        {
          publicKey = cfg.relayPublicKey;
          endpoint = "127.0.0.1:51871";
          persistentKeepalive = 25;
          allowedIPs = [ "0.0.0.0/0" ];
        }
      ];
    };

    systemd = {
      services = {
        ${wgService} = {
          after = [
            wstunnelUnit
            "pangolin.service"
          ];
          # Requisite checks Pangolin without starting it after a deliberate stop.
          requisite = [ "pangolin.service" ];
          requires = [ wstunnelUnit ];
          partOf = [ "pangolin.service" ];
        };

        wstunnel-pangolin-fallback = {
          description = "WireGuard fallback WebSocket transport";
          # Strict reverse-path filtering needs the firewall's reply-marking rule.
          bindsTo = [ "firewall.service" ];
          after = [ "firewall.service" ];
          partOf = [ wgUnit ];
          serviceConfig = {
            ExecStart = lib.concatStringsSep " " [
              (lib.getExe pkgs.wstunnel)
              "client"
              "--socket-so-mark 51871"
              "--tls-verify-certificate"
              "--tls-sni-override ${lib.escapeShellArg cfg.relayHost}"
              "--http-headers ${lib.escapeShellArg "Host: ${cfg.relayHost}"}"
              "-L ${lib.escapeShellArg "udp://127.0.0.1:51871:127.0.0.1:51820?timeout_sec=0"}"
              (lib.escapeShellArg "wss://${cfg.relayIPv4}:443")
            ];
            Restart = "on-failure";
            RestartSec = 2;
            UnsetEnvironment = [
              "HTTP_PROXY"
              "HTTPS_PROXY"
              "ALL_PROXY"
              "NO_PROXY"
              "http_proxy"
              "https_proxy"
              "all_proxy"
              "no_proxy"
            ];
          };
        };

        pangolin-fallback-reconcile = {
          description = "Reconcile the Pangolin fallback with the primary network";
          after = [
            "NetworkManager.service"
            "pangolin.service"
          ];
          partOf = [ "pangolin.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = controller;
          };
        };

      };
      timers.pangolin-fallback-reconcile = {
        description = "Periodically reconcile the Pangolin fallback";
        # Also start on a rebuild when Pangolin is already running.
        wantedBy = [
          "multi-user.target"
          "pangolin.service"
        ];
        partOf = [ "pangolin.service" ];
        timerConfig = {
          OnActiveSec = "1s";
          OnUnitInactiveSec = "5s";
          AccuracySec = "1s";
          Unit = "pangolin-fallback-reconcile.service";
        };
      };
    };
  };
}
