{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };
  home.packages = with pkgs; [
    jetbrains.idea-ultimate
    keepassxc
    krita
    riot-desktop
    steam
    mpv
    mumble
  ];
  programs.firefox = {
    enable = true;
    extensions = with pkgs.nur.repos.rycee.firefox-addons; [
      keepassxc-browser
    ublock-origin
    umatrix
    cookie-autodelete
    dark-night-mode
    ];
  };

  services.nextcloud-client.enable = true;
}