final: prev: {
  mia = prev.callPackage ./packages/mia/package.nix { };

  metals = prev.metals.overrideAttrs (old: {
    version = "1.6.7";
    deps = old.deps.overrideAttrs (_: {
      outputHash = "sha256-2ly1vO+06EalQjEekRwm/g2wfdbq26IcEQscfM14Gvc=";
    });
  });
}
