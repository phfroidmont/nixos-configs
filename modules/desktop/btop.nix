{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.btop;
  btop =
    (pkgs.btop.override {
      cudaSupport = true;
      rocmSupport = true;
    }).overrideAttrs
      (oldAttrs: {
        # https://github.com/aristocratos/btop/issues/1011
        patches = (oldAttrs.patches or [ ]) ++ [ ./align-gpu-summary.patch ];
      });
in
{
  options.modules.desktop.btop = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {
    users.users.${config.user.name}.extraGroups = [
      "render"
      "video"
    ];

    home-manager.users.${config.user.name} =
      { ... }:
      {
        programs.btop = {
          enable = true;
          package = btop;
          settings = {
            color_theme = "gruvbox_dark";
            show_gpu_info = "On";
            vim_keys = true;
          };
        };
      };
  };
}
