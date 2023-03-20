{ inputs, config, lib, pkgs, ... }:
{

  environment.pathsToLink = [ "/share/zsh" ];
  home-manager.users.froidmpa = { config, ... }: {

    imports = [
      ./froidmpa/alacritty.nix
      ./froidmpa/neovim.nix
      ./froidmpa/mpd.nix
      ./froidmpa/dunst.nix
      ./froidmpa/htop.nix
      ./froidmpa/zsh.nix
      ./froidmpa/vscode.nix
      inputs.nix-doom-emacs.hmModule
    ];

    xsession = {
      enable = true;
      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
        config = ./files/xmonad.hs;
      };
      initExtra = ''
        keepassxc &
      '';
      numlock.enable = true;
    };

    services = {
      nextcloud-client.enable = true;
      udiskie.enable = true;
      gpg-agent = {
        enable = true;
        enableSshSupport = false;
        pinentryFlavor = "gtk2";
      };
      stalonetray = {
        enable = true;
        config = {
          geometry = "1x1-5+0";
          background = "#000000";
          transparent = true;
          grow_gravity = "E";
          icon_gravity = "E";
          icon_size = "24";
          kludges = "force_icons_size";
        };
      };
      unclutter.enable = true;
      pasystray.enable = true;
      screen-locker = {
        enable = false;
        inactiveInterval = 5;
        lockCmd = "${pkgs.i3lock}/bin/i3lock -e -f -c 000000 -i ~/.wallpaper.png";
      };
      emacs = {
        enable = true;
        client.enable = true;
      };
    };

    programs = {
      gpg.enable = true;
      git = {
        enable = true;
        userName = "Paul-Henri Froidmont";
        userEmail = "git.contact-57n2p@froidmont.org";
        signing = {
          key = lib.mkDefault "3AC6F170F01133CE393BCD94BE948AFD7E7873BE";
          signByDefault = true;
        };
        extraConfig = {
          init.defaultBranch = "master";
        };
      };
      ssh = {
        enable = true;
        extraConfig = ''
          # Force IPv4 otherwise git will try to use IPv6 which doesn't play well through a VPN
          AddressFamily inet
        '';
      };
      rofi = {
        enable = true;
        theme = "gruvbox-dark";
        terminal = "alacritty";
      };
      bat.enable = true;
      jq.enable = true;
      fzf.enable = true;
      lesspipe.enable = true;
      zathura.enable = true;
      pazi.enable = true;

      broot = {
        enable = true;
        enableZshIntegration = true;
      };
      command-not-found.enable = true;
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
      doom-emacs = {
        enable = true;
        doomPrivateDir = ./files/doom.d;
        emacsPackagesOverlay = final: prev: {
          ob-ammonite = with final; (trivialBuild {
            src = pkgs.fetchFromGitHub {
              owner = "zwild";
              repo = "ob-ammonite";
              rev = "39937dff395e70aff76a4224fa49cf2ec6c57cca";
              sha256 = pkgs.lib.fakeSha256;
            };
            pname = "ob-ammonite";
            packageRequires = [ s dash editorconfig ];
          });
        };
      };
      newsboat = {
        enable = true;
        autoReload = true;
        urls = [
          { title = "Happy Path Programming"; tags = [ "podcast" "programming" ]; url = "https://anchor.fm/s/2ed56aa0/podcast/rss"; }
          { title = "Antoine Goya"; tags = [ "video" "culture" "cinema" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC2qlgiYCCtaYpn2_blX01xg"; }
          { title = "Berd"; tags = [ "video" "humor" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCRei8TBpt4r0WPZ7MkiKmVg"; }
          { title = "Berm Peak"; tags = [ "video" "MTB" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCu8YylsPiu9XfaQC74Hr_Gw"; }
          { title = "Berm Peak Express"; tags = [ "video" "MTB" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCOpP5PqrzODWpFU961acUbg"; }
          { title = "code- Reinho"; tags = [ "video" "guns" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCNWs0QTTHm7yiPMwl0aynsg"; }
          { title = "Computerphile"; tags = [ "video" "programming" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC9-y-6csu5WGm29I7JiwpnA"; }
          { title = "Chronik Fiction"; tags = [ "video" "cinema" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCeah3nqu_v6KfpXrCzEARQw"; }
          { title = "Domain of Science"; tags = [ "video" "science" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCxqAWLTk1CmBvZFPzeZMd9A"; }
          { title = "Forged Alliance Forever"; tags = [ "video" "gaming" "faf" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCkAWiUu4QE172kv"; }
          { title = "Grand Angle"; tags = [ "video" "finance" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCWtD8JN9hkxL5TJL_ktaNZA"; }
          { title = "Gyle"; tags = [ "video" "gaming" "cast" "faf" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCzY7MBSgNLZOMxMIFwtf2bw"; }
          { title = "Hygiène Mentale"; tags = [ "video" "philosophy" "zetetic" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCMFcMhePnH4onVHt2-ItPZw"; }
          { title = "Institut des Libertés"; tags = [ "video" "finance" "politics" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCaqUCTIgFDtMhBeKeeejrkA"; }
          { title = "Juste Milieu"; tags = [ "video" "politics" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCXh5HwvbyfD-GUVHLng9aGQ"; }
          { title = "J'suis pas content TV"; tags = [ "video" "politics" "humor" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC9NB2nXjNtRabu3YLPB16Hg"; }
          { title = "Kriss Papillon"; tags = [ "video" "culture" "philosophy" ]; url = "https://odysee.com/$/rss/@Kriss-Papillon:c"; }
          { title = "Kruggsmash"; tags = [ "video" "storytelling" "gaming" ]; url = "https://www.youtube.com/@kruggsmash"; }
          { title = "Kurzgesagt"; tags = [ "video" "science" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCsXVk37bltHxD1rDPwtNM8Q"; }
          { title = "La Gauloiserie"; tags = [ "video" "guns" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC5Ph48LXovwS2hyAGfWwE9A"; }
          { title = "La Pistolerie"; tags = [ "video" "guns" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCvAZXkucE9CVVxb5K8xTjPA"; }
          { title = "Le Précepteur"; tags = [ "video" "philosophy" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCvRgiAmogg7a_BgQ_Ftm6fA"; }
          { title = "La Tronche en Biais"; tags = [ "video" "philosophy" "zetetic" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCq-8pBMM3I40QlrhM9ExXJQ"; }
          { title = "Luke Smith"; tags = [ "video" "linux" "philosophy" ]; url = "https://videos.lukesmith.xyz/feeds/videos.atom"; }
          { title = "Maitre Luger"; tags = [ "video" "guns" "history" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC570onl32MV5vjAnmnjeycg"; }
          { title = "Mental Outlaw"; tags = [ "video" "linux" ]; url = "https://odysee.com/$/rss/@AlphaNerd:8"; }
          { title = "mozinor"; tags = [ "video" "humor" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCTIiKt_Bp4gKlFPtHeB3qGw"; }
          { title = "NixOS"; tags = [ "video" "linux" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC3vIimi9q4AT8EgxYp_dWIw"; }
          { title = "Numberphile"; tags = [ "video" "math" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCoxcjq-8xIDTYp3uz647V5A"; }
          { title = "PostmodernJukebox"; tags = [ "video" "music" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCORIeT1hk6tYBuntEXsguLg"; }
          { title = "r/NixOS"; tags = [ "video" "linux" "reddit" ]; url = "https://www.reddit.com/r/NixOS.rss"; }
          { title = "r/Scala"; tags = [ "video" "linux" "programming" ]; url = "https://www.reddit.com/r/Scala.rss"; }
          { title = "Real Engineering"; tags = [ "video" "science" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCR1IuLEqb6UEA_zQ81kwXfg"; }
          { title = "Real Science"; tags = [ "video" "science" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC176GAQozKKjhz62H8u9vQQ"; }
          { title = "Richard sur Terre"; tags = [ "video" "politics" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCZIR19yr81nmaP0pMfiMwxw"; }
          { title = "Stevius"; tags = [ "video" "history" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCkWzOALDNDee3t9IfYoB2uQ"; }
          { title = "TheDuelist"; tags = [ "video" "gaming" "cast" "faf" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCDDNS1XW0-o1FRPvaR9-pKA"; }
          { title = "Tom Scott"; tags = [ "video" "science" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCBa659QWEk1AI4Tg--mrJ2A"; }
          { title = "Victor Ferry"; tags = [ "video" "rhetoric" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCcueC-4NWGuPFQKzQWn5heA"; }
          { title = "videogamedunkey"; tags = [ "video" "humor" "gaming" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCsvn_Po0SmunchJYOWpOxMg"; }
          { title = "Vilebrequin"; tags = [ "video" "humor" "cars" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCC9mlCpyisiIpp9YA9xV-QA"; }
          { title = "Vsauce"; tags = [ "video" "science" "philosophy" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC6nSFpj9HTCZ5t-N3Rm3-HA"; }
          { title = "Wendover Productions"; tags = [ "video" "finance" "logistics" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC9RM-iSvTu1uPJb8X5yp3EQ"; }
          { title = "Willow's Duality"; tags = [ "video" "gaming" "cast" "faf" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UC8lU7OuwPGDQibMhnvSvf1w"; }
          { title = "ScienceEtonnante"; tags = [ "video" "science" ]; url = "https://www.youtube.com/feeds/videos.xml?channel_id=UCaNlbnghtwlsGF-KzAFThqA"; }
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

    gtk = {
      enable = true;
      theme.name = "oomox-gruvmox-dark-medium-default";
      iconTheme.name = "oomox-gruvmox-dark-medium-default";
    };
    qt = {
      enable = true;
      platformTheme = "gtk";
    };

    home = {
      stateVersion = "20.09";

      sessionVariables = {
        QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      };

      keyboard = {
        layout = "fr";
        options = [ "caps:escape" ];
      };

      file = {
        ".wallpaper.png".source = ./files/wallpaper.png;
        ".xmonad/xmobarrc".source = ./files/xmobarrc;
        ".config/ncmpcpp" = {
          source = ./files/ncmpcpp;
          recursive = true;
        };
        ".xmonad/scripts" = {
          source = ./files/scripts;
          recursive = true;
        };
        ".themes/oomox-gruvmox-dark-medium-default" = {
          source = ./files/oomox-gruvmox-dark-medium-default;
          recursive = true;
        };
        ".config/ranger" = {
          source = ./files/ranger;
          recursive = true;
        };
        ".config/ranger/plugins" = {
          source = builtins.fetchGit {
            url = "git://github.com/phfroidmont/ranger_devicons.git";
            rev = "e02b6a3203411b76616a0e4328245bf8b47c5dcc";
          };
          recursive = true;
        };
      };

      packages = with pkgs.unstable; [
        haskellPackages.xmobar
        i3lock
        ncmpcpp
        mpc_cli
        pulsemixer
        feh
        xorg.xbacklight
        xorg.xinit
        xorg.xwininfo
        xorg.xkill
        scrot
        numix-gtk-theme

        # Ranger preview utils
        w3m
        xclip
        odt2txt

        firefox
        brave
        keepassxc
        krita
        element-desktop
        mpv
        jellyfin-mpv-shim
        mumble
        libreoffice-fresh
        onlyoffice-bin
        thunderbird
        portfolio
        transmission-remote-gtk
        monero-gui

        jdk
        jetbrains.idea-community
        httpie

        rnix-lsp
        metals
        nixpkgs-fmt

        zsh-syntax-highlighting
        ranger
        R
        tldr
        thefuck
        atool
        linuxPackages.perf

        glxinfo
        steam
        protontricks
        lutris
        dolphinEmu
      ];
    };


    systemd.user.services.activitywatch = {
      Unit.Description = "Start ActivityWatch";
      Service.Type = "simple";
      Service.ExecStart = "${pkgs.unstable.activitywatch-bin}/bin/aw-server";
      Install.WantedBy = [ "default.target" ];
      Service.Restart = "on-failure";
      Service.RestartSec = 5;
    };
    systemd.user.services.activitywatch-afk = {
      Unit.Description = "Start ActivityWatch AFK";
      Service.Type = "simple";
      Service.ExecStart = "${pkgs.unstable.activitywatch-bin}/bin/aw-watcher-afk";
      Install.WantedBy = [ "default.target" ];
      Service.Restart = "on-failure";
      Service.RestartSec = 5;
    };
    systemd.user.services.activitywatch-window = {
      Unit.Description = "Start ActivityWatch Window";
      Service.Type = "simple";
      Service.ExecStart = "${pkgs.unstable.activitywatch-bin}/bin/aw-watcher-window";
      Install.WantedBy = [ "default.target" ];
      Service.Restart = "on-failure";
      Service.RestartSec = 5;
    };
  };
}
