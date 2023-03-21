{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.htop;
in {
  options.modules.desktop.htop = {
    enable = mkBoolOpt false;
  };
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = { config, ... }: {
      programs.htop = {
        enable = true;
        settings = {
          hide_userland_threads = true;
          highlight_base_name = true;
          vim_mode = true;
          fields = with config.lib.htop.fields;[
            PID
            USER
            M_RESIDENT
            M_SHARE
            STATE
            PERCENT_CPU
            PERCENT_MEM
            IO_RATE
            TIME
            COMM
          ];
        } // (
          with config.lib.htop; leftMeters [
            (bar "LeftCPUs2")
            (bar "CPU")
            (bar "Memory")
            (bar "Swap")
          ]
        ) // (
          with config.lib.htop; rightMeters [
            (bar "RightCPUs2")
            (text "Tasks")
            (text "LoadAverage")
            (text "Uptime")
          ]
        );
      };
    };
  };
}
