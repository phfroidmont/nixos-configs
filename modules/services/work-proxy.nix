{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.work-proxy;
in
{
  options.modules.services.work-proxy = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      settings = {
        server = [
          "/lefoyer.lu/127.0.0.1#1053"
          "/foyer.lu/127.0.0.1#1053"
          "/foyer.cloud/127.0.0.1#1053"
          "1.1.1.1"
        ];
        no-resolv = true;
        interface = "lo";
        bind-interfaces = true;
      };
    };

    networking = {
      proxy = {
        httpProxy = "http://127.0.0.1:${toString config.services.tinyproxy.settings.Port}";
        httpsProxy = "http://127.0.0.1:${toString config.services.tinyproxy.settings.Port}";
      };
    };

    services.tinyproxy = {
      enable = true;
      settings = {
        LogLevel = "Info";
        Port = 2345;
        Upstream = [
          ''upstream socks5 127.0.0.1:5080 ".lefoyer.lu"''
          ''upstream socks5 127.0.0.1:5080 ".foyer.lu"''
          ''upstream socks5 127.0.0.1:5080 ".foyer.cloud"''
          ''upstream http   127.0.0.1:3128 ".microsoftonline.com"''
        ];
      };
    };

    services.redsocks = {
      enable = false;
      log_debug = true;
      log_info = true;
      redsocks = [
        {
          port = 12345;
          proxy = "127.0.0.1:5080";
          type = "socks5";
          redirectCondition = "-d 10.134.0.0/16";
          doNotRedirect = [
            "-p tcp -m owner --uid-owner redsocks"
            "-p tcp --dport 80"
            "-p tcp --dport 443"
          ];
        }
        # {
        #   port = 12345;
        #   proxy = "127.0.0.1:${toString config.services.tinyproxy.settings.Port}";
        #   type = "http-relay";
        #   redirectCondition = "--dport 80";
        #   doNotRedirect = [
        #     "-p tcp -m owner --uid-owner tinyproxy"
        #   ];
        # }
        # {
        #   port = 12346;
        #   proxy = "127.0.0.1:${toString config.services.tinyproxy.settings.Port}";
        #   type = "http-connect";
        #   redirectCondition = "--dport 443";
        #   doNotRedirect = [
        #     "-p tcp -m owner --uid-owner tinyproxy"
        #   ];
        # }
      ];
    };

    security.pki.certificateFiles = [
      "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ./certs/Foyer-Group-Root-CA.crt
      ./certs/Foyer-Sub-CA.crt
    ];

    environment.variables = {
      JAVAX_NET_SSL_TRUSTSTORE = ./certs/cacerts;
      JAVA_OPTS = "-Dhttp.proxyHost=localhost -Dhttp.proxyPort=${toString config.services.tinyproxy.settings.Port} -Dhttps.proxyHost=localhost -Dhttps.proxyPort=${toString config.services.tinyproxy.settings.Port} -Djavax.net.ssl.trustStore=${./certs/cacerts} -Djavax.net.ssl.trustStorePassword=changeit";
    };

    home-manager.users.${config.user.name} = {
      home = {
        file.".sbt/repositories".text = ''
          [repositories]
            local
            maven-local
            nexus-maven: https://nexus.foyer.lu/repository/mvn-all/
            nexus-ivy: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext]
            nexus-ivy-sbt: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[artifact](-[classifier])-[type].[ext]
        '';
      };
    };

    environment.systemPackages = with pkgs; [ chisel ];
  };
}
