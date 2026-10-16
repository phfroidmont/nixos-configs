{ inputs }:
final: prev:

let
  quickshellPanelTools = import ./packages/quickshell-panel-tools/package.nix {
    pkgs = final;
    inherit inputs;
  };
  quickshellPackage = inputs.quickshell.packages.${final.stdenv.hostPlatform.system}.quickshell;
in
{
  fos = prev.callPackage ./packages/fos/package.nix {
    panelTools = quickshellPanelTools;
    inherit inputs quickshellPackage;
  };
  quickshell-panel-tools = quickshellPanelTools;
  get-token = prev.callPackage ./packages/get-token/package.nix { };
  jellyfin-cli = prev.callPackage ./packages/jellyfin-cli/package.nix { };
  voyager-firmware = prev.callPackage ./packages/voyager-firmware/package.nix {
    qmkFirmware = inputs.qmk-firmware;
  };
  voyager-flash = prev.writeShellApplication {
    name = "voyager-flash";
    runtimeInputs = [ prev.zapp ];
    text = ''
      exec zapp flash ${final.voyager-firmware}/zsa_voyager_azerty.bin
    '';
  };
  mia = prev.callPackage ./packages/mia/package.nix { };
}
