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
  };

  services.tinyproxy = {
    enable = true;
    settings = {
      LogLevel = "Info";
      Port = 2345;
      Listen = "0.0.0.0";
      Upstream = [
        ''upstream socks5 127.0.0.1:5080 ".tailscale.com"''
        ''upstream socks5 127.0.0.1:5080 "hs.banditlair.com"''
        # ''upstream http 127.0.0.1:3128 "hs.banditlair.com"''
        ''upstream http 127.0.0.1:3128 "login.microsoftonline.com"''
      ];
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

  systemd.services.tailscaled.serviceConfig.Environment = [
    "HTTPS_PROXY=http://127.0.0.1:2345"
  ];

  modules = {
    editor = {
      vim.enable = true;
    };
    desktop.file-manager.enable = true;
    desktop.zsh.enable = true;
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
      command-not-found.enable = true;
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
