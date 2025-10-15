{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.services.kanata;
in
{
  options.modules.services.kanata = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    services.kanata = {
      enable = true;
      keyboards.laptop.config = ''
        ;; QWERTY-shaped matrix; works for AZERTY because Kanata uses scancodes.
        (defsrc
          esc 1 2 3 4 5 6 7 8 9 0 - = bspc
          tab q w e r t y u i o p [ ] \
          caps a s d f g h j k l ; ' ret
          lsft z x c v b n m , . / rsft
          lctl lmet lalt spc ralt rmet rctl
        )

        (defvar
          tap-time 150
          hold-time 200
        )

        ;; Home-row mod-taps (tap sends the letter; hold sends the modifier)
        (defalias
          a-alt (tap-hold $tap-time $hold-time a lalt)
          s-ctl (tap-hold $tap-time $hold-time s lctl)
          d-sft (tap-hold $tap-time $hold-time d lsft)
          f-met (tap-hold $tap-time $hold-time f lmet)

          j-met (tap-hold $tap-time $hold-time j rmet)
          k-sft (tap-hold $tap-time $hold-time k rsft)
          l-ctl (tap-hold $tap-time $hold-time l rctl)
          ;-alt (tap-hold $tap-time $hold-time ; ralt)
        )

        (deflayer main
          esc 1 2 3 4 5 6 7 8 9 0 - = bspc
          tab q w e r t y u i o p [ ] \
          caps @a-alt @s-ctl @d-sft @f-met g h @j-met @k-sft @l-ctl @;-alt ' ret
          lsft z x c v b n m , . / rsft
          lctl lmet lalt spc ralt rmet rctl
        )
      '';
    };

  };
}
