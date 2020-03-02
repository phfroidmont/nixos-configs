{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    wget
    inetutils

    man

    dos2unix

    vim
    git
    zip
    unzip

    htop
    ncdu
    nload
    pciutils
  ];
  fonts = {
    fonts = with pkgs; [
      meslo-lg
      nerdfonts
    ];
    fontconfig.defaultFonts = {
      monospace = [ "MesloLGMDZ Nerd Font Mono" ];
    };
  };

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  users.users.froidmpa = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  programs.ssh.startAgent = true;
  services.xserver = {
    enable = true;
    layout = "fr";
    desktopManager.xterm.enable = false;
    windowManager.xmonad.enable = true;
    displayManager.lightdm = {
      enable = true;
      background = "/etc/nixos/configs/files/wallpaper.png";
    };
  };
}
