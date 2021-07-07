{ config, lib, pkgs, ... }:
{

  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };
  home.packages = with pkgs; [
    firefox
    brave
    keepassxc
    krita
    element-desktop
    mpv
    mumble
    libreoffice-fresh
    thunderbird
    portfolio
    transmission-remote-gtk
    monero-gui
  ];
  services.nextcloud-client.enable = true;
  services.udiskie.enable = true;
}
