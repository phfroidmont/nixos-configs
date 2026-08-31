{
  bash,
  bluez,
  brightnessctl,
  btop,
  coreutils,
  curl,
  ethtool,
  fwupd,
  glab,
  gnugrep,
  gnused,
  grim,
  hyprland,
  hyprlock,
  inetutils,
  iproute2,
  iputils,
  iw,
  jq,
  lib,
  libnotify,
  libvirt,
  lm_sensors,
  lshw,
  mpc,
  networkmanager,
  nh,
  nix,
  nvme-cli,
  pciutils,
  playerctl,
  power-profiles-daemon,
  procps,
  pulseaudio,
  pulsemixer,
  replaceVars,
  runCommand,
  satty,
  shellcheck,
  slurp,
  smartmontools,
  symlinkJoin,
  systemd,
  tailscale,
  tesseract,
  upower,
  usbutils,
  util-linux,
  wf-recorder,
  wireplumber,
  writeShellApplication,
  wl-clipboard,
  wdisplays,
  zsh,
  panelTools ? null,
  quickshellPackage ? null,
}:

let
  completion = replaceVars ./_fos {
    timeout = lib.getExe' coreutils "timeout";
  };
  application = writeShellApplication {
    name = "fos";
    runtimeInputs = [
      bluez
      brightnessctl
      btop
      coreutils
      curl
      ethtool
      fwupd
      glab
      gnugrep
      gnused
      grim
      hyprland
      hyprlock
      procps
      inetutils
      iproute2
      iputils
      iw
      jq
      libnotify
      libvirt
      lm_sensors
      lshw
      mpc
      networkmanager
      nh
      nix
      nvme-cli
      pciutils
      playerctl
      power-profiles-daemon
      pulseaudio
      pulsemixer
      satty
      slurp
      smartmontools
      systemd
      tailscale
      tesseract
      upower
      usbutils
      util-linux
      wf-recorder
      wireplumber
      wl-clipboard
      wdisplays
    ]
    ++ lib.optional (panelTools != null) panelTools
    ++ lib.optional (quickshellPackage != null) quickshellPackage;
    text = builtins.replaceStrings [ "@fos-uptime@" ] [ (lib.getExe' procps "uptime") ] (
      builtins.readFile ./fos.sh
    );
  };
  package = symlinkJoin {
    name = "fos";
    paths = [ application ];
    postBuild = ''
      ${lib.getExe zsh} -n ${completion}
      mkdir -p $out/share/zsh/site-functions
      ln -s ${completion} $out/share/zsh/site-functions/_fos
    '';
    meta = {
      description = "Froidmont Operating System command center";
      mainProgram = "fos";
      platforms = lib.platforms.linux;
    };
  };
  tests =
    runCommand "fos-tests"
      {
        nativeBuildInputs = [
          bash
          coreutils
          gnugrep
          jq
          shellcheck
          zsh
        ];
      }
      ''
            shellcheck ${./fos.sh} ${./test.sh}
            zsh -n ${completion}
        FOS_BIN=${lib.getExe package} FOS_COMPLETION=${package}/share/zsh/site-functions/_fos FOS_SOURCE=${./fos.sh} ${lib.getExe bash} ${./test.sh}
            touch $out
      '';
in
package.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or { }) // {
    inherit tests;
  };
})
