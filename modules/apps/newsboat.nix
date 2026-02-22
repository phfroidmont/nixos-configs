{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.modules.apps.newsboat;
in
{
  options.modules.apps.newsboat = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      programs.newsboat = {
        enable = true;
        autoFetchArticles = {
          enable = true;
          onCalendar = "hourly";
        };
        extraConfig = ''
          urls-source "ocnews"
          ocnews-url "https://cloud.banditlair.com"
          ocnews-login "paultrial"
          ocnews-passwordeval "${pkgs.libsecret}/bin/secret-tool lookup elfeed nextcloud"

          cleanup-on-quit yes

          bind gg everywhere home
          bind G everywhere end

          bind u everywhere toggle-article-read

          bind , everywhere sort

          bind ^u everywhere pageup
          bind ^d everywhere pagedown

          bind k everywhere up
          bind j everywhere down

          bind l feedlist open
          bind l articlelist open
          bind h articlelist quit
          bind h article quit
        '';
      };
    };
  };
}
