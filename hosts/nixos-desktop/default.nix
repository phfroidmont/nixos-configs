{ pkgs, config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  modules = {
    desktop = {
      xmonad.enable = true;
      neovim.enable = true;
      alacritty.enable = true;
      zsh.enable = true;
      vscode.enable = true;
      dunst.enable = true;
      htop.enable = true;
      mpd.enable = true;
    };
  };

  # Allow to externally control MPD
  networking.firewall.allowedTCPPorts = [ 6600 ];

  system.stateVersion = "20.09";
}
