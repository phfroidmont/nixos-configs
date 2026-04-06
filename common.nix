{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ]
  ++ (lib.my.mapModulesRec' (toString ./modules) import);

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
      !include /etc/nix/access-tokens.conf
    '';
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      netrc-file = "/etc/nix/netrc";
      "extra-sandbox-paths" = [
        "/etc/nix/netrc"
        "/etc/nix/curlrc"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://devenv.cachix.org"
        # "ssh://nix-ssh@hel1.banditlair.com"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "hel1.banditlair.com:stzB4xe5QTFvSABoP11ZpNzLDCRZ93PExk0Z/gOzW3g="
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
      persistent = true;
    };
  };

  systemd.services.nix-daemon.serviceConfig.Environment = [
    "NIX_CURL_FLAGS=-K/etc/nix/curlrc"
  ];

  system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;

  time.timeZone = lib.mkDefault "Europe/Amsterdam";

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  zramSwap.enable = true;
  zramSwap.memoryPercent = 300;
  systemd.oomd.enable = lib.mkDefault true;

  console = {
    keyMap = lib.mkDefault "fr";
    font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    earlySetup = true;
  };

  fonts.fontconfig.antialias = lib.mkDefault true;
  fonts.fontconfig.subpixel = {
    rgba = lib.mkDefault "none";
    lcdfilter = lib.mkDefault "none";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    glab
    (writeShellScriptBin "refresh-nix-gitlab-token" ''
      #!/usr/bin/env bash
      set -euo pipefail

      HOST="''${1:-gitlab.com}"
      TOKEN="$(glab config get token --host "$HOST" -g)"

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

    wget
    inetutils
    man

    htop-vim
    ncdu
    nload
    pciutils
    lsof
    dnsutils

    unzip
  ];

  networking.hosts = {
    "127.0.0.1" = [
      "localhost"
      "membres.yourcoop.local"
    ];
  };
  services.resolved.dnssec = "false";
}
