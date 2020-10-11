{ config, lib, pkgs, ... }:
{

  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };
  home.packages = with pkgs; [
    firefox
    keepassxc
    krita
    element-desktop
    mpv
    mumble
    libreoffice-fresh
    slack
    thunderbird
    zoom-us
  ];
  services.nextcloud-client.enable = true;
}
