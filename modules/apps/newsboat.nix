{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.apps.newsboat;
in {
  options.modules.apps.newsboat = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      programs.newsboat = {
        enable = true;
        autoReload = true;
        urls = [
          {
            title = "Happy Path Programming";
            tags = [ "podcast" "programming" ];
            url = "https://anchor.fm/s/2ed56aa0/podcast/rss";
          }
          {
            title = "Antoine Goya";
            tags = [ "video" "culture" "cinema" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC2qlgiYCCtaYpn2_blX01xg";
          }
          {
            title = "Berd";
            tags = [ "video" "humor" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCRei8TBpt4r0WPZ7MkiKmVg";
          }
          {
            title = "Berm Peak";
            tags = [ "video" "MTB" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCu8YylsPiu9XfaQC74Hr_Gw";
          }
          {
            title = "Berm Peak Express";
            tags = [ "video" "MTB" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCOpP5PqrzODWpFU961acUbg";
          }
          {
            title = "code- Reinho";
            tags = [ "video" "guns" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCNWs0QTTHm7yiPMwl0aynsg";
          }
          {
            title = "Computerphile";
            tags = [ "video" "programming" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC9-y-6csu5WGm29I7JiwpnA";
          }
          {
            title = "Chronik Fiction";
            tags = [ "video" "cinema" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCeah3nqu_v6KfpXrCzEARQw";
          }
          {
            title = "Domain of Science";
            tags = [ "video" "science" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCxqAWLTk1CmBvZFPzeZMd9A";
          }
          {
            title = "Forged Alliance Forever";
            tags = [ "video" "gaming" "faf" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCkAWiUu4QE172kv-ZuyR42w";
          }
          {
            title = "Grand Angle";
            tags = [ "video" "finance" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCWtD8JN9hkxL5TJL_ktaNZA";
          }
          {
            title = "Gyle";
            tags = [ "video" "gaming" "cast" "faf" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCzY7MBSgNLZOMxMIFwtf2bw";
          }
          {
            title = "Hygiène Mentale";
            tags = [ "video" "philosophy" "zetetic" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCMFcMhePnH4onVHt2-ItPZw";
          }
          {
            title = "Institut des Libertés";
            tags = [ "video" "finance" "politics" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCaqUCTIgFDtMhBeKeeejrkA";
          }
          {
            title = "Juste Milieu";
            tags = [ "video" "politics" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCXh5HwvbyfD-GUVHLng9aGQ";
          }
          {
            title = "J'suis pas content TV";
            tags = [ "video" "politics" "humor" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC9NB2nXjNtRabu3YLPB16Hg";
          }
          {
            title = "Kriss Papillon";
            tags = [ "video" "culture" "philosophy" ];
            url = "https://odysee.com/$/rss/@Kriss-Papillon:c";
          }
          {
            title = "Kruggsmash";
            tags = [ "video" "storytelling" "gaming" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCaifrB5IrvGNPJmPeVOcqBA";
          }
          {
            title = "Kurzgesagt";
            tags = [ "video" "science" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCsXVk37bltHxD1rDPwtNM8Q";
          }
          {
            title = "La Gauloiserie";
            tags = [ "video" "guns" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC5Ph48LXovwS2hyAGfWwE9A";
          }
          {
            title = "La Pistolerie";
            tags = [ "video" "guns" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCvAZXkucE9CVVxb5K8xTjPA";
          }
          {
            title = "Le Précepteur";
            tags = [ "video" "philosophy" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCvRgiAmogg7a_BgQ_Ftm6fA";
          }
          {
            title = "La Tronche en Biais";
            tags = [ "video" "philosophy" "zetetic" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCq-8pBMM3I40QlrhM9ExXJQ";
          }
          {
            title = "Luke Smith";
            tags = [ "video" "linux" "philosophy" ];
            url = "https://videos.lukesmith.xyz/feeds/videos.atom";
          }
          {
            title = "Maitre Luger";
            tags = [ "video" "guns" "history" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC570onl32MV5vjAnmnjeycg";
          }
          {
            title = "Mental Outlaw";
            tags = [ "video" "linux" ];
            url = "https://odysee.com/$/rss/@AlphaNerd:8";
          }
          {
            title = "mozinor";
            tags = [ "video" "humor" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCTIiKt_Bp4gKlFPtHeB3qGw";
          }
          {
            title = "NixOS";
            tags = [ "video" "linux" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC3vIimi9q4AT8EgxYp_dWIw";
          }
          {
            title = "Numberphile";
            tags = [ "video" "math" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCoxcjq-8xIDTYp3uz647V5A";
          }
          {
            title = "PostmodernJukebox";
            tags = [ "video" "music" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCORIeT1hk6tYBuntEXsguLg";
          }
          {
            title = "r/NixOS";
            tags = [ "video" "linux" "reddit" ];
            url = "https://www.reddit.com/r/NixOS.rss";
          }
          {
            title = "r/Scala";
            tags = [ "video" "linux" "programming" ];
            url = "https://www.reddit.com/r/Scala.rss";
          }
          {
            title = "Real Engineering";
            tags = [ "video" "science" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCR1IuLEqb6UEA_zQ81kwXfg";
          }
          {
            title = "Real Science";
            tags = [ "video" "science" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC176GAQozKKjhz62H8u9vQQ";
          }
          {
            title = "Richard sur Terre";
            tags = [ "video" "politics" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCZIR19yr81nmaP0pMfiMwxw";
          }
          {
            title = "Stevius";
            tags = [ "video" "history" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCkWzOALDNDee3t9IfYoB2uQ";
          }
          {
            title = "TheDuelist";
            tags = [ "video" "gaming" "cast" "faf" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCDDNS1XW0-o1FRPvaR9-pKA";
          }
          {
            title = "Tom Scott";
            tags = [ "video" "science" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCBa659QWEk1AI4Tg--mrJ2A";
          }
          {
            title = "Victor Ferry";
            tags = [ "video" "rhetoric" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCcueC-4NWGuPFQKzQWn5heA";
          }
          {
            title = "videogamedunkey";
            tags = [ "video" "humor" "gaming" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCsvn_Po0SmunchJYOWpOxMg";
          }
          {
            title = "Vilebrequin";
            tags = [ "video" "humor" "cars" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCC9mlCpyisiIpp9YA9xV-QA";
          }
          {
            title = "Vsauce";
            tags = [ "video" "science" "philosophy" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC6nSFpj9HTCZ5t-N3Rm3-HA";
          }
          {
            title = "Wendover Productions";
            tags = [ "video" "finance" "logistics" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC9RM-iSvTu1uPJb8X5yp3EQ";
          }
          {
            title = "Willow's Duality";
            tags = [ "video" "gaming" "cast" "faf" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UC8lU7OuwPGDQibMhnvSvf1w";
          }
          {
            title = "ScienceEtonnante";
            tags = [ "video" "science" ];
            url =
              "https://www.youtube.com/feeds/videos.xml?channel_id=UCaNlbnghtwlsGF-KzAFThqA";
          }
        ];
        extraConfig = ''
          macro v set browser "setsid -f ${pkgs.mpv}/bin/mpv --really-quiet --no-terminal" ; open-in-browser ; set browser brave

          # unbind keys
          unbind-key ENTER
          unbind-key j
          unbind-key k
          unbind-key J
          unbind-key K

          # bind keys - vim style
          bind-key j down
          bind-key k up
          bind-key l open
          bind-key h quit

          color background          color223   color0
          color listnormal          color223   color0
          color listnormal_unread   color2     color0
          color listfocus           color223   color237
          color listfocus_unread    color223   color237
          color info                color8     color0
          color article             color223   color0

          # highlights
          highlight article "^(Feed|Link):.*$" color11 default bold
          highlight article "^(Title|Date|Author):.*$" color11 default bold
          highlight article "https?://[^ ]+" color2 default underline
          highlight article "\\[[0-9]+\\]" color2 default bold
          highlight article "\\[image\\ [0-9]+\\]" color2 default bold
          highlight feedlist "^─.*$" color6 color6 bold
        '';
      };
    };
  };
}
