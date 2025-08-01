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

    networking = {
      proxy = {
        httpProxy = "http://127.0.0.1:${toString config.services.tinyproxy.settings.Port}";
        httpsProxy = "http://127.0.0.1:${toString config.services.tinyproxy.settings.Port}";
      };
    };

    services.tinyproxy = {
      enable = true;
      settings = {
        Port = 2345;
        Upstream = [
          ''upstream socks5 localhost:5080 ".lefoyer.lu"''
          ''upstream socks5 localhost:5080 ".foyer.lu"''
          ''upstream socks5 localhost:5080 ".foyer.cloud"''
          ''upstream http localhost:3128 ".microsoftonline.com"''
        ];
      };
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
      home.file.".sbt/repositories".text = ''
        [repositories]
          local
          maven-local
          nexus-maven: https://nexus.foyer.lu/repository/mvn-all/
          nexus-ivy: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext]
          nexus-ivy-sbt: https://nexus.foyer.lu/repository/ivy-all/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[artifact](-[classifier])-[type].[ext]
      '';
    };

    # users.users.${config.user.name}.extraGroups = [ "work-proxyd" ];
    #
    # environment.systemPackages = with pkgs; [ virt-manager ];
  };
}
