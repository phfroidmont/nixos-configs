{ config, lib, pkgs, ... }:
let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec -a "$0" "$@"
  '';
in
{
  imports = [
    <home-manager/nixos>
    ./hardware-configuration.nix
    ../../configs/system.nix
    ../../configs/network.nix
    ../../configs/virtualisation.nix
  ];

  hardware.nvidia.prime = {
    offload.enable = true;

    # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
    intelBusId = "PCI:0:2:0";

    # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
    nvidiaBusId = "PCI:1:0:0";
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices = {
    crypted = {
      device = "/dev/disk/by-uuid/50f8d5be-eabc-4b80-a36f-b8e5646c4fc1";
      preLVM = true;
    };
  };

  boot.kernel.sysctl = {
    # Turn on execshield
    "kernel.exec-shield" = 1;
    "kkernel.randomize_va_space" = 1;
    # Enable IP spoofing protection
    "net.ipv4.conf.all.rp_filter" = 1;
    # Disable IP source routing
    "knet.ipv4.conf.all.accept_source_route" = 0;
    # Ignoring broadcasts request
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "fnet.ipv4.icmp_ignore_bogus_error_messages" = 1;
    # Make sure spoofed packets get logged
    "net.ipv4.conf.all.log_martians" = 1;
    #  SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;
    # Control IP packet forwarding
    "net.ipv4.ip_forward" = 1;
  };

  networking = {
    hostName = "enix016";
    networkmanager = {
      enable = true;
      dns = "dnsmasq";
    #  extraConfig = ''
    #      rc-manager=unmanaged
    #  '';
    };
  };

  #services.dnsmasq = {
  #  enable = true;
  #  servers = [
  #    "1.1.1.1"
  #    "1.0.0.1"
  #    "/.its/172.21.1.131"
  #    "/.its/172.21.1.146"
  #    "/.lab.ingenico.com/172.24.15.1"
  #    "/.lab.ingenico.com/172.24.15.2"
  #    "/.sandbox.global.ingenico.com/10.138.24.53"
  #    "/sb.eu.ginfra.net/10.138.24.53"
  #  ];
  #  extraConfig = ''
  #      addn-hosts=/etc/hosts
  #      interface=lo
  #      interface=docker0
  #      bind-dynamic
  #      listen-address=172.17.0.1
  #  '';
  #};

#  networking.interfaces.wlp59s0.useDHCP = true;

  console = {
    font = "Lat2-Terminus16";
    keyMap = "fr";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  time.timeZone = "Europe/Amsterdam";

  environment.etc = {
   "openfortivpn/config".text = ''
        host = devsslvpn.global.ingenico.com
        port = 443
        trusted-cert = e09de6da3902e58b9061f28e13d33088d929f3451367d21f1721a0ed6361a883
        trusted-cert = 33069b6d904330b3fde5c002ca4964b7f413003665e78963d73098fe5f6f7c05
        trusted-cert = 599dba9bee8a920836b68ca5603a11ceee5ec0450201c7a7651f5575d6bbcd3a
        set-dns = 0
        set-routes = 1
        insecure-ssl = 0
        cipher-list = HIGH:!aNULL:!kRSA:!PSK:!SRP:!MD5:!RC4
      '';
   "NetworkManager/dnsmasq.d/hosts.conf".text = ''
        addn-hosts=/etc/hosts
      '';
   "NetworkManager/dnsmasq.d/ingenico.conf".text = ''
        server=/.its/172.21.1.131
        server=/.its/172.21.1.146
        server=/.lab.ingenico.com/172.24.15.1
        server=/.lab.ingenico.com/172.24.15.2
        server=/.sandbox.global.ingenico.com/10.138.24.53
        server=/sb.eu.ginfra.net/10.138.24.53
      '';
   "NetworkManager/dnsmasq.d/default.conf".text = ''
        server=/~./1.1.1.1
        server=1.1.1.1
        server=/~./1.0.0.1
        server=1.0.0.1
      '';
   "docker/daemon.json".text = ''
        {
          "dns": [
            "10.138.24.53",
            "172.17.0.1"
          ],
          "insecure-registries": [
            "docker-registry.services.lab.ingenico.com"
          ]
        }
      '';
   "NetworkManager/dnsmasq.d/docker-bridge.conf".text = ''
        interface=lo
        interface=docker0
        listen-address=172.17.0.1
      '';
  };

  hardware.bluetooth = {
    enable = true;
    # Enable A2DP Sink
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  hardware.pulseaudio = {
    enable = true;

    # Use full build to have Bluetooth support
    package = pkgs.pulseaudioFull;
  };

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    imports = [
      ../../configs/home/full.nix
    ];
    services = {
      network-manager-applet.enable = true;
      blueman-applet.enable = true;
      grobi = {
        enable = true;
        executeAfter = ["${pkgs.systemd}/bin/systemctl --user restart stalonetray" "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.png"];
        rules = [
          {
            name = "Work HDMI";
            outputs_connected = [ "HDMI-1" ];
            configure_single = "HDMI-1";
            primary = true;
            atomic = true;
          }
          {
            name = "Work dock";
            outputs_connected = [ "DP-1-2" ];
            configure_single = "DP-1-2";
            primary = true;
            atomic = true;
          }
          {
            name = "Work USBC";
            outputs_connected = [ "DP-1" ];
            configure_single = "DP-1";
            primary = true;
            atomic = true;
          }
          {
            name = "Fallback";
            configure_single = "eDP-1";
          }
        ];
      };
      gpg-agent = {
        enable = true;
        enableSshSupport = false;
        pinentryFlavor = "gtk2";
      };
    };

    programs = {
      git = {
        enable = true;
        userName  = "Paul-Henri Froidmont";
        userEmail = "paul-henri.froidmont@ingenico.com";
        signing = {
          key = "589ECB6FAA8FF1F40E579C9E1479473F99393013";
          signByDefault = true;
        };
        lfs.enable = true;
      };
      gpg.enable = true;
    };
  };
  # Enable touchpad support.
  services.xserver.libinput.enable = true;

  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];
  services.avahi.enable = true;
  services.avahi.nssmdns = true;
  # eid
  services.pcscd.enable = true;
  environment.systemPackages = with pkgs; [
    eid-mw
    nvidia-offload
  ];

  system.stateVersion = "20.09";
}

