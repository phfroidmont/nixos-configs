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
  metals = prev.metals.overrideAttrs (oldAttrs: {
    extraJavaOpts = prev.lib.concatStringsSep " " [
      oldAttrs.extraJavaOpts
      "--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.jvm=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.resources=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED"
      "--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED"
      "--add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED"
      "--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED"
      "--add-opens=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED"
      "--add-opens=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED"
    ];
  });
  mia = prev.callPackage ./packages/mia/package.nix { };
}
