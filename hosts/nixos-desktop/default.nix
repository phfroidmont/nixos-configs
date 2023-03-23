{ pkgs, config, lib, ... }: {
  imports = [ ./hardware-configuration.nix ];

  modules = {
    hardware = { audio.enable = true; };
    desktop = {
      xmonad.enable = true;
      alacritty.enable = true;
      zsh.enable = true;
      vscode.enable = true;
      dunst.enable = true;
      htop.enable = true;
    };
    editor = {
      vim.enable = true;
      emacs.enable = true;
    };
    services = {
      flatpak.enable = true;
      belgian-eid.enable = true;
      docker.enable = true;
      libvirt.enable = true;
    };
    apps = { newsboat.enable = true; };
    media = {
      mpd.enable = true;
      ncmpcpp.enable = true;
      emulators.gc.enable = true;
      steam.enable = true;
      lutris.enable = true;
    };
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Allow to externally control MPD
  networking.firewall.allowedTCPPorts = [ 6600 ];

  system.stateVersion = "20.09";
}
