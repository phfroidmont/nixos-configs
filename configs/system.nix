{ config, lib, pkgs, ... }:
{

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  environment.systemPackages = with pkgs; [
    (pkgs.writeShellScriptBin "nixFlakes" ''
      exec ${pkgs.nixUnstable}/bin/nix --experimental-features "nix-command flakes" "$@"
    '')

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
  ];
  fonts = {
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "Meslo" ]; })
    ];
    fontconfig.defaultFonts = {
      monospace = [ "MesloLGMDZ Nerd Font Mono" ];
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

  # Required for custom GTK themes
  services.dbus.packages = with pkgs; [ gnome3.dconf ];
}
