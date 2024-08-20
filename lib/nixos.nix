{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  sys = "x86_64-linux";
in
rec {
  mkHost =
    path:
    attrs@{
      system ? sys,
      ...
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit lib inputs system;
      };
      modules = [
        {
          nixpkgs.pkgs = pkgs;
          nix.registry.nixpkgs.flake = inputs.nixpkgs;
          networking.hostName = lib.mkDefault (lib.removeSuffix ".nix" (baseNameOf path));
        }
        (lib.filterAttrs (n: v: !lib.elem n [ "system" ]) attrs)
        ../common.nix
        (import path)
      ];
    };

  mapHosts =
    dir:
    attrs@{
      system ? system,
      ...
    }:
    lib.my.mapModules dir (hostPath: mkHost hostPath attrs);
}
