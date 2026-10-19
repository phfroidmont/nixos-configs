{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Every .nix file under dir, skipping names that start with "_". A directory's
  # default.nix is listed with the directory's siblings, before its other files.
  findModules =
    dir:
    let
      entries = lib.filterAttrs (name: _: !lib.hasPrefix "_" name) (builtins.readDir dir);
      isModule =
        name: type:
        (type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name)
        || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"));
      modules = lib.attrNames (lib.filterAttrs isModule entries);
      directories = lib.attrNames (lib.filterAttrs (_: type: type == "directory") entries);
    in
    map (name: dir + "/${name}") modules
    ++ lib.concatMap (name: findModules (dir + "/${name}")) directories;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.nix-index
  ]
  ++ findModules ./modules;

  programs.command-not-found.enable = false;
  programs.nix-index-database.comma.enable = true;

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    settings = {
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://devenv.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
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
    gh
    vim
    glab
    wget
    inetutils
    man

    btop
    dua
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
  services.resolved.settings.Resolve.DNSSEC = "false";
}
