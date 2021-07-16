{ config, lib, pkgs, ... }:
{

  home-manager.users.froidmpa = { pkgs, config, ... }: {
    #    nixpkgs.config = {
    #      allowUnfree = true;
    #      packageOverrides = super:
    #        let self = super.pkgs; in
    #        {
    #          lutris-unwrapped = super.lutris-unwrapped.overridePythonAttrs (oldAttrs: rec {
    #            patches = [
    #              ./lutris_sort_new_with_model_fix.patch
    #            ];
    #          });
    #        };
    #    };
    #    home.packages = with pkgs; [
    #      steam
    #      dolphinEmu
    #    ];
  };
}
