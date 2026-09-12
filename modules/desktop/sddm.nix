{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.sddm;
  c = (import ./themes/_palette.nix).semantic;
  theme = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura_static";
    themeConfig = {
      Font = "MesloLGS Nerd Font Propo";
      FontSize = 16;
      DateFormat = "dd/MM/yyyy";

      Background = "${config.modules.desktop.wallpaper}";
      CropBackground = true;
      DimBackground = 0.55;
      DimBackgroundColor = c.bgStrong;

      FormPosition = "center";
      HaveFormBackground = false;

      HeaderTextColor = c.accent;
      DateTextColor = c.fg;
      TimeTextColor = c.fg;
      FormBackgroundColor = c.bg;
      BackgroundColor = c.bg;

      LoginFieldBackgroundColor = c.bgAlt;
      PasswordFieldBackgroundColor = c.bgAlt;
      LoginFieldTextColor = c.fg;
      PasswordFieldTextColor = c.fg;
      UserIconColor = c.accent;
      PasswordIconColor = c.accent;
      PlaceholderTextColor = c.fgMuted;
      WarningColor = c.critical;

      LoginButtonTextColor = c.bgStrong;
      LoginButtonBackgroundColor = c.accent;
      SystemButtonsIconsColor = c.accent;
      SessionButtonTextColor = c.fg;
      DropdownTextColor = c.fg;
      DropdownSelectedBackgroundColor = c.bgHover;
      DropdownBackgroundColor = c.bg;
      HighlightTextColor = c.bgStrong;
      HighlightBackgroundColor = c.accent;
      HighlightBorderColor = c.accent;

      HoverUserIconColor = c.fg;
      HoverPasswordIconColor = c.fg;
      HoverSystemButtonsIconsColor = c.fg;
      HoverSessionButtonTextColor = c.accent;

      HideSystemButtons = false;
      HideLoginButton = false;
      ForceLastUser = true;
      PasswordFocus = true;
    };
  };
in
{
  options.modules.desktop.sddm.enable = lib.my.mkBoolOpt false;

  config = lib.mkIf cfg.enable {
    services.displayManager.autoLogin.enable = false;

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      extraPackages = [ theme ];
    };

    environment.systemPackages = [ theme ];
    fonts.packages = [ pkgs.nerd-fonts.meslo-lg ];
  };
}
