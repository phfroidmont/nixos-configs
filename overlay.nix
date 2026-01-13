final: prev: {
  activitywatch-bin = prev.callPackage ./packages/activitywatch.nix { };
  mia = prev.callPackage ./packages/mia/package.nix { };
}
