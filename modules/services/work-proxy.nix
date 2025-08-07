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

    services.tinyproxy = {
      enable = true;
      settings = {
        LogLevel = "Info";
        Port = 2345;
        Upstream = [
          ''upstream http wsl:2345 ".microsoftonline.com"''
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
      JAVA_OPTS = "-Djavax.net.ssl.trustStore=${./certs/cacerts} -Djavax.net.ssl.trustStorePassword=changeit";
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
