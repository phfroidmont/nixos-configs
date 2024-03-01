{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.themes.qt;

  sddmBackground = pkgs.fetchurl {
    url =
      "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/main/wallpapers/irl/mountains2.jpg";
    sha256 = "sha256-hp9cxCpZsDYKxUUSuec2wZyv9/N93Cw6ENTHGxKap9Q=";
  };

  sddmTheme = pkgs.stdenv.mkDerivation {
    name = "sddm-theme";
    src = pkgs.fetchFromGitHub {
      owner = "MarianArlt";
      repo = "sddm-sugar-dark";
      rev = "ceb2c455663429be03ba62d9f898c571650ef7fe";
      sha256 = "0153z1kylbhc9d12nxy9vpn0spxgrhgy36wy37pk6ysq7akaqlvy";
    };
    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
      cd $out/
      rm Background.jpg
      cp -r ${sddmBackground} $out/Background.jpg
    '';
  };

in {
  options.modules.desktop.themes.qt = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.xserver.displayManager.sddm.theme = "${sddmTheme}";

    environment.systemPackages = with pkgs; [
      libsForQt5.qt5.qtquickcontrols2
      libsForQt5.qt5.qtgraphicaleffects
    ];

    home-manager.users.${config.user.name} = {

      qt = {
        enable = true;
        platformTheme = "gtk";
        style = {
          name = "adwaita-dark";
          package = pkgs.unstable.adwaita-qt;
        };
      };
    };
  };
}
