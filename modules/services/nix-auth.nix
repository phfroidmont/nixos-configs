{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.nix-auth;
in
{
  options.modules.services.nix-auth = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    nix = {
      extraOptions = lib.mkAfter ''
        !include /etc/nix/access-tokens.conf
      '';
      settings = {
        netrc-file = "/etc/nix/netrc";
        "extra-sandbox-paths" = [
          "/etc/nix/netrc"
          "/etc/nix/curlrc"
        ];
      };
    };

    systemd.services.nix-daemon.serviceConfig.Environment = [
      "NIX_CURL_FLAGS=-K/etc/nix/curlrc"
    ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "refresh-nix-gitlab-token" ''
        #!/usr/bin/env bash
        set -euo pipefail

        HOST="''${1:-gitlab.com}"
        TOKEN="$(${pkgs.glab}/bin/glab config get token --host "$HOST" -g)"

        if [[ -z "$TOKEN" ]]; then
          echo "No token found for $HOST in glab config" >&2
          echo "Run: glab auth login" >&2
          exit 1
        fi

        sudo install -d -m 0755 /etc/nix
        sudo sh -c 'umask 077; printf "access-tokens = %s=PAT:%s\n" "$1" "$2" > /etc/nix/access-tokens.conf' _ "$HOST" "$TOKEN"
        sudo install -m 0640 -g nixbld /dev/null /etc/nix/netrc
        sudo sh -c 'cat > /etc/nix/netrc <<EOF
        machine $1
        login oauth2
        password $2
        EOF' _ "$HOST" "$TOKEN"
        sudo install -m 0644 /dev/null /etc/nix/curlrc
        sudo sh -c 'printf "netrc-file = /etc/nix/netrc\n" > /etc/nix/curlrc'
        sudo systemctl restart nix-daemon

        echo "Updated /etc/nix/access-tokens.conf, /etc/nix/netrc and /etc/nix/curlrc, then restarted nix-daemon."
      '')
    ];
  };
}
