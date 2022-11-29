{ config, lib, pkgs, nixpkgs, ... }:
{

  nix = {
    package = pkgs.nixUnstable;
    settings = {
      extra-sandbox-paths = [
        "/var/keys/netrc"
      ];
      substituters = [
        "http://cache.banditlair.com"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "cache.banditlair.com:4zk7iDvzKh6VN+LxzKIGcVPKgL5dLeyEt2ydrgx4o8c="
      ];
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    nixPath = [
      "nixpkgs=${nixpkgs}"
    ];
  };

  environment.systemPackages = with pkgs; [
    wget
    inetutils
    openvpn
    openfortivpn

    man

    dos2unix

    vim
    git
    git-lfs
    zip
    unzip

    htop
    ncdu
    nload
    pciutils
    lsof
    dnsutils
  ];
  nixpkgs.config.allowUnfree = true;
  fonts = {
    fonts = with pkgs; [
      corefonts # Microsoft free fonts
      meslo-lgs-nf
    ];
    fontconfig.defaultFonts = {
      monospace = [ "MesloLGS NF" ];
    };
  };

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

  services.udisks2.enable = true;

  systemd.packages = [ pkgs.dconf ];

  # Required for custom GTK themes
  services.dbus.packages = with pkgs; [ dconf ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
