{ config, lib, pkgs, ... }:
{

  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };
  home.packages = with pkgs; [
    keepassxc
    krita
    riot-desktop
    mpv
    mumble
    libreoffice-fresh
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
