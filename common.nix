{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ] ++ (lib.my.mapModulesRec' (toString ./modules) import);

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = "experimental-features = nix-command flakes";
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      substituters = [
        "https://nix-community.cachix.org"
        "http://cache.banditlair.com"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.banditlair.com:4zk7iDvzKh6VN+LxzKIGcVPKgL5dLeyEt2ydrgx4o8c="
      ];
      auto-optimise-store = true;
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
