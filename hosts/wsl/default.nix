{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
{

  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  user.name = "nixos";

  wsl = {
    enable = true;
    wslConf = {
      network.generateHosts = false;
      network.generateResolvConf = false;
      wsl2.memory = "24GB";
      interop.appendWindowsPath = false;
    };
  };

  networking = {
    nameservers = [
      "10.33.0.100"
      "10.33.1.30"
      "1.1.1.1"
    ];
    proxy = {
      httpProxy = "http://127.0.0.1:3128";
      httpsProxy = "http://127.0.0.1:3128";
      noProxy = ".lefoyer.lu,.foyer.lu,.foyer.cloud,localhost,127.0.0.1";
    };
    nat = {
      enable = true;
      internalInterfaces = [ "wg0" ];
      externalInterface = "eth0";
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.rp_filter" = lib.mkForce 0;
    "net.ipv4.conf.wg0.rp_filter" = lib.mkForce 0;
    "net.ipv4.conf.eth0.rp_filter" = lib.mkForce 0;
  };

  services.tinyproxy = {
    enable = true;
    settings = {
      LogLevel = "Info";
      Port = 2345;
      Listen = "0.0.0.0";
      Upstream = [
        ''upstream http 127.0.0.1:3128 "login.microsoftonline.com"''
      ];
    };
  };

  systemd.services.wstunnel-wg = {
    description = "wstunnel client for WireGuard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.wstunnel}/bin/wstunnel client --http-proxy http://127.0.0.1:3128 --tls-verify-certificate --log-lvl INFO -L udp://51820:127.0.0.1:51820?timeout_sec=0 wss://ws.banditlair.com:443";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  networking.wg-quick.interfaces.wg0 = {
    autostart = true;
    address = [ "10.250.250.2/30" ];
    mtu = 1300;
    privateKeyFile = "/etc/secrets/wg-wsl.key";
    peers = [
      {
        publicKey = "ycPnsgWTOgJzPTWi0y9BOLZQ8lwwGlpkp3i/QTjBXRk=";
        endpoint = "127.0.0.1:51820";
        persistentKeepalive = 20;
        allowedIPs = [
          "10.250.250.1/32"
        ];
      }
    ];
  };

  systemd.services.wg-quick-wg0 = {
    after = [ "wstunnel-wg.service" ];
    wants = [ "wstunnel-wg.service" ];
  };

  systemd.services.wg-wsl-nat = {
    description = "NAT and forwarding rules for wg0";
    wantedBy = [ "wg-quick-wg0.service" ];
    partOf = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];
    requires = [ "wg-quick-wg0.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -euc '${pkgs.iptables}/bin/iptables -C FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null || ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT; ${pkgs.iptables}/bin/iptables -C FORWARD -i eth0 -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || ${pkgs.iptables}/bin/iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; ${pkgs.iptables}/bin/iptables -t nat -C POSTROUTING -s 10.250.250.0/30 -o eth0 -j MASQUERADE 2>/dev/null || ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.250.250.0/30 -o eth0 -j MASQUERADE'";
      ExecStop = "${pkgs.bash}/bin/bash -euc '${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -D FORWARD -i eth0 -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.250.250.0/30 -o eth0 -j MASQUERADE 2>/dev/null || true'";
    };
  };

  modules = {
    editor = {
      vim.enable = true;
    };
    desktop.file-manager.enable = true;
    desktop.zsh.enable = true;
    ai.opencode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    scala-cli
    jdk17
    httpie
    zsh-syntax-highlighting
    tldr
    nil
    coursier
    nodejs
    imagemagick
    (sbt.override { jre = jdk17; })
    mill
    kafkactl
  ];

  security.pki.certificateFiles = [
    "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ../../modules/services/certs/Foyer-Group-Root-CA.crt
    ../../modules/services/certs/Foyer-Sub-CA.crt
  ];

  environment.variables = {
    JAVAX_NET_SSL_TRUSTSTORE = "/mnt/c/Users/RDO/scoop/apps/java21/current/lib/security/cacerts";
    JAVA_OPTS = "-Dhttp.proxyHost=localhost -Dhttp.proxyPort=3128 -Dhttps.proxyHost=localhost -Dhttps.proxyPort=3128 -Djavax.net.ssl.trustStore=/mnt/c/Users/RDO/scoop/apps/java21/current/lib/security/cacerts -Djavax.net.ssl.trustStorePassword=changeit";
  };

  home-manager.users.${config.user.name} = {
    home.file.".sbt/repositories".text = ''
      [repositories]
        local
        maven-local
        nexus-maven: https://nexus.foyer.lu/repository/mvn-all/
        nexus-ivy: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext]
        nexus-ivy-sbt: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[artifact](-[classifier])-[type].[ext]
    '';

    programs = {
      git = {
        enable = true;
        userName = "Paul-Henri Froidmont";
        userEmail = "rdo@foyer.lu";
        extraConfig = {
          init.defaultBranch = "master";
          http.sslVerify = false;
        };
      };
      bat.enable = true;
      jq.enable = true;
      fzf.enable = true;
      lesspipe.enable = true;
      pazi.enable = true;
      broot = {
        enable = true;
        enableZshIntegration = true;
      };
      nix-index = {
        enable = true;
        enableZshIntegration = true;
      };
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      # LogLevel = "DEBUG";
    };
  };

  system.stateVersion = "24.05";
}
