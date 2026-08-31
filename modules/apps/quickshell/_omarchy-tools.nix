{ pkgs }:

let
  scripts = ./omarchy/scripts;
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
  tools = [
    (mkTool "omarchy-audio-input-set-default" (
      commonInputs
      ++ (with pkgs; [
        pulseaudio
        wireplumber
      ])
    ) "audio-input-set-default.sh")
    (mkTool "omarchy-audio-output-set-default" (
      commonInputs
      ++ (with pkgs; [
        pulseaudio
        wireplumber
      ])
    ) "audio-output-set-default.sh")
    (mkTool "omarchy-audio-output-sink" (commonInputs ++ [ pkgs.pulseaudio ]) "audio-output-sink.sh")
    (mkTool "omarchy-audio-sink-availability" (
      commonInputs ++ [ pkgs.pulseaudio ]
    ) "audio-sink-availability.sh")
    (mkTool "omarchy-battery-low" (commonInputs ++ [ pkgs.libnotify ]) "battery-low.sh")
    (mkTool "omarchy-battery-status" commonInputs "battery-status.sh")
    (mkTool "omarchy-bluetooth-device" (
      commonInputs
      ++ (with pkgs; [
        bluez
        util-linux
      ])
    ) "bluetooth-device.sh")
    (mkTool "omarchy-bluetooth-power" (
      commonInputs
      ++ (with pkgs; [
        bluez
        util-linux
      ])
    ) "bluetooth-power.sh")
    (mkTool "omarchy-brightness-display" (
      commonInputs
      ++ (with pkgs; [
        brightnessctl
        hyprland
        jq
      ])
    ) "brightness-display.sh")
    (mkTool "omarchy-display-text-size" commonInputs "display-text-size.sh")
    (mkTool "omarchy-hyprland-monitor-scaling" (
      commonInputs
      ++ (with pkgs; [
        hyprland
        jq
      ])
    ) "monitor-scaling.sh")
    (mkTool "omarchy-monitor-state" (
      commonInputs
      ++ (with pkgs; [
        hyprland
        jq
      ])
    ) "monitor-state.sh")
    (mkTool "omarchy-network-band" (
      commonInputs
      ++ (with pkgs; [
        iw
        networkmanager
      ])
    ) "network-band.sh")
    (mkTool "omarchy-network-password" (commonInputs ++ [ pkgs.networkmanager ]) "network-password.sh")
    (mkTool "omarchy-network-qr" (
      commonInputs
      ++ (with pkgs; [
        networkmanager
        qrencode
      ])
    ) "network-qr.sh")
    (mkTool "omarchy-network-speedtest" (
      commonInputs
      ++ (with pkgs; [
        curl
        iproute2
        jq
      ])
    ) "network-speedtest.sh")
    (mkTool "omarchy-network-status" (
      commonInputs
      ++ (with pkgs; [
        iproute2
        iputils
        iw
        jq
        networkmanager
      ])
    ) "network-status.sh")
    (mkTool "omarchy-notification-send" (commonInputs ++ [ pkgs.libnotify ]) "notification-send.sh")
    (mkTool "omarchy-powerprofiles-list" (
      commonInputs ++ [ pkgs.power-profiles-daemon ]
    ) "powerprofiles-list.sh")
    (mkTool "omarchy-powerprofiles-set" (
      commonInputs
      ++ (with pkgs; [
        power-profiles-daemon
        systemd
      ])
    ) "powerprofiles-set.sh")
    (mkTool "omarchy-system-stats" commonInputs "system-stats.sh")
    (mkTool "omarchy-weather-location" (
      commonInputs
      ++ (with pkgs; [
        curl
        jq
      ])
    ) "weather-location.sh")
    (mkTool "omarchy-weather-status" (
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
