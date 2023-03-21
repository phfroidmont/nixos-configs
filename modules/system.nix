{ config, lib, pkgs, nixpkgs, ... }:
{

  environment.systemPackages = with pkgs.unstable; [
    wget
    inetutils
    man

    zip
    unzip

    ripgrep
    fd
    findutils.locate

    htop
    ncdu
    nload
    pciutils
    lsof
    dnsutils
  ];

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  programs.adb.enable = true;

  users.users.froidmpa = {
    isNormalUser = true;
    extraGroups = [ "wheel" "adbusers" ];
    shell = pkgs.zsh;
  };

  programs.ssh.startAgent = true;

  services.udisks2.enable = true;

  systemd.packages = [ pkgs.dconf ];

  # Required for custom GTK themes
  services.dbus.packages = with pkgs; [ dconf ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
