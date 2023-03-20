{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
{
  imports =
    [ inputs.home-manager.nixosModules.home-manager ];
  # ++ (mapModulesRec' (toString ./modules) import);

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";
    nixPath = [
      "nixpkgs=${inputs.nixpkgs-unstable}"
    ];
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
  system.configurationRevision = with inputs; mkIf (self ? rev) self.rev;

  environment.systemPackages = with pkgs; [
    git
    vim
  ];
}
