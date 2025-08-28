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
    extraOptions = "experimental-features = nix-command flakes";
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://devenv.cachix.org"
        "ssh://nix-ssh@hel1.banditlair.com"
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

  system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;

  time.timeZone = lib.mkDefault "Europe/Amsterdam";

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

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
