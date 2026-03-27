let
  mkHex = value: "#${value}";
  mkRgb = value: "rgb(${value})";

  base = {
    bg0Hard = "1d2021";
    bg0 = "282828";
    bg0Soft = "32302f";
    bg1 = "3c3836";
    bg2 = "504945";
    bg3 = "665c54";

    fg0 = "fbf1c7";
    fg1 = "ebdbb2";
    fg4 = "a89984";

    red = "fb4934";
    orange = "fe8019";
    yellow = "fabd2f";
    green = "b8bb26";
    aqua = "8ec07c";
    blue = "83a598";
    purple = "d3869b";
  };

  hex = builtins.mapAttrs (_: mkHex) base;
  rgb = builtins.mapAttrs (_: mkRgb) base;
in
{
  inherit base hex rgb;

  semantic = {
    bg = hex.bg0;
    bgAlt = hex.bg1;
    bgHover = hex.bg3;
    bgStrong = hex.bg0Hard;

    fg = hex.fg1;
    fgMuted = hex.fg4;

    accent = hex.orange;
    info = hex.blue;
    success = hex.green;
    warning = hex.yellow;
    critical = hex.red;

    borderActiveRgb = rgb.orange;
    borderInactiveRgb = rgb.bg2;

    lockInnerRgb = rgb.bg0Soft;
    lockOuterRgb = rgb.orange;
    lockTextRgb = rgb.fg1;
  };
}
