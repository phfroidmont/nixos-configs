final: prev:
{
  ncmpcpp = prev.ncmpcpp.override { visualizerSupport = true; };
  firefox = prev.firefox.override { pkcs11Modules = [ prev.eid-mw ]; };
  activitywatch-bin = prev.callPackage ./packages/activitywatch.nix { };
}
