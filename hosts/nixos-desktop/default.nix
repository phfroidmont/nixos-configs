{ pkgs, config, lib, ... }: {
  imports = [ ./hardware-configuration.nix ];

  modules = {
    desktop.hyprland.enable = true;
    editor = {
      vim.enable = true;
      emacs.enable = true;
    };
    services = {
      flatpak.enable = true;
      belgian-eid.enable = true;
      docker.enable = true;
      libvirt.enable = true;
      languagetool.enable = true;
    };
    media = {
      mpd.enable = true;
      ncmpcpp.enable = true;
      emulators.gc.enable = true;
      steam.enable = true;
      lutris.enable = true;
    };
  };

  programs.kdeconnect.enable = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Allow to externally control MPD
  networking.firewall.allowedTCPPorts = [ 6600 ];

  system.stateVersion = "20.09";
}
