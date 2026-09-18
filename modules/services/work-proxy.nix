{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.work-proxy;
  pacScript = ''
    function FindProxyForURL(url, host) {
      if (host.toLowerCase() === "login.microsoftonline.com") {
        return "PROXY wsl.foyer.internal:2345";
      }

      return "DIRECT";
    }
  '';
  # Both browsers accept an embedded PAC, so no HTTP server is needed.
  pacUrl = "data:application/x-ns-proxy-autoconfig,${lib.escapeURL pacScript}";
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
    environment.etc = {
      # Firefox reads this instead of package-level distribution policies.
      "firefox/policies/policies.json".text = builtins.toJSON {
        policies.Proxy = {
          Mode = "autoConfig";
          AutoConfigURL = pacUrl;
          Locked = true;
        };
      };
      "brave/policies/managed/work-proxy.json".text = builtins.toJSON {
        ProxySettings = {
          ProxyMode = "pac_script";
          ProxyPacUrl = pacUrl;
          ProxyPacMandatory = true;
        };
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

    environment.systemPackages = with pkgs; [
      (sbt.override { jre = jdk25; })
      mongodbCompass
      chisel
      get-token
      mia
      jira-cli-go
    ];
  };
}
