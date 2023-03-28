{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.picom;
in {
  options.modules.desktop.picom = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      services.picom = {
        backend = "glx";
        vSync = true;
        opacityRules = [
          # "100:class_g = 'Firefox'"
          # Art/image programs where we need fidelity
          "100:class_g = 'Gimp'"
          "100:class_g = 'Inkscape'"
          "100:class_g = 'aseprite'"
          "100:class_g = 'krita'"
          "100:class_g = 'feh'"
          "100:class_g = 'mpv'"
          "100:class_g = 'Rofi'"
          "100:class_g = 'Peek'"
          "99:_NET_WM_STATE@:32a = '_NET_WM_STATE_FULLSCREEN'"
        ];
        shadowExclude = [
          # Put shadows on notifications, the scratch popup and rofi only
          "! name~='(rofi|scratch|Dunst)$'"
        ];

        fade = true;
        fadeDelta = 1;
        fadeSteps = [ 1.0e-2 1.2e-2 ];
        shadow = true;
        shadowOffsets = [ (-10) (-10) ];
        shadowOpacity = 0.22;
        # activeOpacity = "1.00";
        # inactiveOpacity = "0.92";
        #
        settings = {
          blur-background-exclude = [
            "window_type = 'dock'"
            "window_type = 'desktop'"
            "class_g = 'Rofi'"
            "_GTK_FRAME_EXTENTS@:c"
          ];

          # Unredirect all windows if a full-screen opaque window is detected, to
          # maximize performance for full-screen windows. Known to cause
          # flickering when redirecting/unredirecting windows.
          unredir-if-possible = true;

          # GLX backend: Avoid using stencil buffer, useful if you don't have a
          # stencil buffer. Might cause incorrect opacity when rendering
          # transparent content (but never practically happened) and may not work
          # with blur-background. My tests show a 15% performance boost.
          # Recommended.
          glx-no-stencil = true;

          # Use X Sync fence to sync clients' draw calls, to make sure all draw
          # calls are finished before picom starts drawing. Needed on
          # nvidia-drivers with GLX backend for some users.
          xrender-sync-fence = true;

          shadow-radius = 12;
          # blur-background = true;
          # blur-background-frame = true;
          # blur-background-fixed = true;
          blur-kern = "7x7box";
          blur-strength = 320;
        };
      };
    };
  };
}
