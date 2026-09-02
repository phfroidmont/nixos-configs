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
  hyprpicker,
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
  voxtype,
  wf-recorder,
  wireplumber,
  writeShellApplication,
  wl-clipboard,
  wdisplays,
  zsh,
  inputs,
  panelTools ? null,
  quickshellPackage ? null,
}:

let
  completion = replaceVars ./_fos {
    timeout = lib.getExe' coreutils "timeout";
  };
  dollar = "$";
  captureRegionSource = builtins.readFile "${inputs.omarchy}/bin/omarchy-capture-region";
  smartClickSelection = builtins.concatStringsSep "\n" [
    "      if ((click_x >= rect_x && click_x < rect_x + rect_width && click_y >= rect_y && click_y < rect_y + rect_height)); then"
    "        SELECTION=\"${dollar}{rect_x},${dollar}{rect_y} ${dollar}{rect_width}x${dollar}{rect_height}\""
    "        break"
    "      fi"
  ];
  smallestSmartClickSelection = builtins.concatStringsSep "\n" [
    "      area=$((rect_width * rect_height))"
    "      if ((click_x >= rect_x && click_x < rect_x + rect_width && click_y >= rect_y && click_y < rect_y + rect_height && ( ${dollar}{smallest_area:-0} == 0 || area < smallest_area ) )); then"
    "        SELECTION=\"${dollar}{rect_x},${dollar}{rect_y} ${dollar}{rect_width}x${dollar}{rect_height}\""
    "        smallest_area=$area"
    "      fi"
  ];
  captureRegionText =
    let
      patched =
        builtins.replaceStrings [ smartClickSelection ] [ smallestSmartClickSelection ]
          captureRegionSource;
    in
    assert patched != captureRegionSource;
    patched;
  captureRegion = writeShellApplication {
    name = "fos-internal-capture-region";
    bashOptions = [ ];
    excludeShellChecks = [
      "SC2016"
      "SC2155"
    ];
    runtimeInputs = [
      coreutils
      hyprland
      hyprpicker
      jq
      procps
      slurp
    ];
    text = captureRegionText;
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
      hyprpicker
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
      voxtype
      wf-recorder
      wireplumber
      wl-clipboard
      wdisplays
    ]
    ++ [ captureRegion ]
    ++ lib.optional (panelTools != null) panelTools
    ++ lib.optional (quickshellPackage != null) quickshellPackage;
    text =
      builtins.replaceStrings
        [
          "@fos-satty@"
          "@fos-uptime@"
        ]
        [
          (lib.getExe satty)
          (lib.getExe' procps "uptime")
        ]
        (builtins.readFile ./fos.sh);
  };
  package = symlinkJoin {
    name = "fos";
    paths = [
      application
      captureRegion
    ];
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
        if grep -Fq 'set -o errexit' ${captureRegion}/bin/fos-internal-capture-region; then
          printf '%s\n' 'capture region helper must preserve upstream cancellation handling' >&2
          exit 1
        fi
        FOS_BIN=${lib.getExe package} FOS_COMPLETION=${package}/share/zsh/site-functions/_fos FOS_SOURCE=${./fos.sh} ${lib.getExe bash} ${./test.sh}
            touch $out
      '';
in
package.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or { }) // {
    inherit tests;
  };
})
