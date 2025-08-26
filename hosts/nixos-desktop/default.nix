{ pkgs, config, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  modules = {
    desktop.wm.enable = true;
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
      work-proxy.enable = true;
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
  # nix = {
  #   distributedBuilds = true;
  #   buildMachines = [
  #     {
  #       hostName = "hel1.banditlair.com";
  #       sshUser = "nix-ssh";
  #       system = "x86_64-linux";
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #   ];
  #   settings = {
  #     builders-use-substitutes = true;
  #   };
  # };

  services.tailscale.enable = true;

  # Allow to externally control MPD
  networking.firewall.allowedTCPPorts = [ 6600 ];

  system.stateVersion = "20.09";
}
