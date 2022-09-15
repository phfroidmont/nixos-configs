{}:
final: prev:
{
  ncmpcpp = prev.ncmpcpp.override { visualizerSupport = true; };
  firefox = prev.firefox.override { pkcs11Modules = [ prev.eid-mw ]; };
  exodus = prev.exodus.overrideDerivation (old: {
    src = prev.fetchurl {
      url = "https://downloads.exodus.com/releases/${old.pname}-linux-x64-${old.version}.zip";
      sha256 = "sha256-rizVb3Yckd0ionRunT7VRq+wJvtNffkk3QzxTYQgvnY=";
    };
    unpackCmd = ''
      ${prev.unzip}/bin/unzip "$src" -x "Exodus*/lib*so"
    '';
  });

  activitywatch-bin = prev.callPackage ./packages/activitywatch.nix { };
}
