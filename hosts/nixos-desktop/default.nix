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

  user.name = "froidmpa";

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

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    listenAddresses = [
      {
        # Tailscale interface
        addr = "100.64.0.3";
        port = 22;
      }
    ];
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../ssh_keys/phfroidmont-laptop.pub
    ../../ssh_keys/phfroidmont-stellaris.pub
  ];

  # Allow to externally control MPD
  networking.firewall.allowedTCPPorts = [ 6600 ];

  home-manager.users.${config.user.name} =
    { ... }:
    {
      wayland.windowManager.hyprland.settings = {
        monitor = [
          "DP-1, 4096x2160@240, 0x0, 1.5"
        ];
      };
    };

  system.stateVersion = "20.09";
}
