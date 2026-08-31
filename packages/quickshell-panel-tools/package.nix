{ inputs, pkgs }:

let
  scripts = ../../modules/apps/quickshell/omarchy/scripts;
  commonInputs = with pkgs; [
    coreutils
    gawk
    gnugrep
    gnused
  ];
  mkTool =
    name: runtimeInputs: file:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (scripts + "/${file}");
    };
  notificationSend = pkgs.writeShellApplication {
    name = "fos-internal-notification-send";
    excludeShellChecks = [ "SC1083" ];
    runtimeInputs = with pkgs; [
      jq
      systemd
    ];
    text =
      builtins.replaceStrings [ "omarchy-notification-send" ] [ "fos-internal-notification-send" ]
        (builtins.readFile "${inputs.omarchy}/bin/omarchy-notification-send");
  };
  tools = [
    (mkTool "fos-internal-audio-input-set-default" (
      commonInputs
      ++ (with pkgs; [
        pulseaudio
        wireplumber
      ])
    ) "audio-input-set-default.sh")
    (mkTool "fos-internal-audio-output-set-default" (
      commonInputs
      ++ (with pkgs; [
        pulseaudio
        wireplumber
      ])
    ) "audio-output-set-default.sh")
    (mkTool "fos-internal-audio-output-sink" (
      commonInputs ++ [ pkgs.pulseaudio ]
    ) "audio-output-sink.sh")
    (mkTool "fos-internal-audio-sink-availability" (
      commonInputs ++ [ pkgs.pulseaudio ]
    ) "audio-sink-availability.sh")
    (mkTool "fos-internal-battery-low" (commonInputs ++ [ notificationSend ]) "battery-low.sh")
    (mkTool "fos-internal-battery-status" commonInputs "battery-status.sh")
    (mkTool "fos-internal-bluetooth-device" (
      commonInputs
      ++ (with pkgs; [
        bluez
        util-linux
      ])
    ) "bluetooth-device.sh")
    (mkTool "fos-internal-bluetooth-power" (
      commonInputs
      ++ (with pkgs; [
        bluez
        util-linux
      ])
    ) "bluetooth-power.sh")
    (mkTool "fos-internal-brightness-display" (
      commonInputs
      ++ (with pkgs; [
        brightnessctl
        hyprland
        jq
      ])
    ) "brightness-display.sh")
    (mkTool "fos-internal-display-text-size" commonInputs "display-text-size.sh")
    (mkTool "fos-internal-hyprland-monitor-scaling" (
      commonInputs
      ++ (with pkgs; [
        hyprland
        jq
      ])
    ) "monitor-scaling.sh")
    (mkTool "fos-internal-monitor-state" (
      commonInputs
      ++ (with pkgs; [
        hyprland
        jq
      ])
    ) "monitor-state.sh")
    (mkTool "fos-internal-network-band" (
      commonInputs
      ++ (with pkgs; [
        iw
        networkmanager
      ])
    ) "network-band.sh")
    (mkTool "fos-internal-network-password" (
      commonInputs ++ [ pkgs.networkmanager ]
    ) "network-password.sh")
    (mkTool "fos-internal-network-qr" (
      commonInputs
      ++ (with pkgs; [
        networkmanager
        qrencode
      ])
    ) "network-qr.sh")
    (mkTool "fos-internal-network-speedtest" (
      commonInputs
      ++ (with pkgs; [
        curl
        iproute2
        jq
      ])
    ) "network-speedtest.sh")
    (mkTool "fos-internal-network-status" (
      commonInputs
      ++ (with pkgs; [
        iproute2
        iputils
        iw
        jq
        networkmanager
      ])
    ) "network-status.sh")
    notificationSend
    (mkTool "fos-internal-powerprofiles-list" (
      commonInputs ++ [ pkgs.power-profiles-daemon ]
    ) "powerprofiles-list.sh")
    (mkTool "fos-internal-powerprofiles-set" (
      commonInputs
      ++ (with pkgs; [
        power-profiles-daemon
        systemd
      ])
    ) "powerprofiles-set.sh")
    (mkTool "fos-internal-system-stats" commonInputs "system-stats.sh")
    (mkTool "fos-internal-weather-location" (
      commonInputs
      ++ (with pkgs; [
        curl
        jq
      ])
    ) "weather-location.sh")
    (mkTool "fos-internal-weather-status" (
      commonInputs
      ++ (with pkgs; [
        curl
        jq
      ])
    ) "weather-status.sh")
    (mkTool "nextcloud-status" (
      commonInputs
      ++ (with pkgs; [
        jq
        systemd
      ])
    ) "nextcloud-status.sh")
  ];
in
pkgs.symlinkJoin {
  name = "quickshell-panel-tools";
  paths = tools;
}
