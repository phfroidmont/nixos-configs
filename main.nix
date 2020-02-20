{ config, pkgs, ... }:
{
  imports = [
    <home-manager/nixos>
  ];


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    inetutils

    man

    vim
    git

    htop
    ncdu
  ];
  fonts = {
    fonts = with pkgs; [
      meslo-lg
      nerdfonts
    ];
    fontconfig.defaultFonts = {
      monospace = [ "MesloLGMDZ Nerd Font Mono" ];
    };
  };

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  services.xserver = {
    enable = true;
    layout = "fr";
    desktopManager.xterm.enable = false;
    windowManager.xmonad.enable = true;
  };

  users.users.froidmpa = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    xsession = {
      enable = true;
      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
        config = ./conf/xmonad.hs;
      };
    };
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.packageOverrides = pkgs: {
      ncmpcpp = pkgs.ncmpcpp.override {visualizerSupport = true;};
      nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
        inherit pkgs;
      };
    };
    home.packages = with pkgs; [
      jetbrains.idea-ultimate
      haskellPackages.xmobar
      keepassxc
      zsh-syntax-highlighting
      ncmpcpp
      mpc_cli
      pulsemixer
      krita
      feh
      riot-desktop
      steam
      xorg.xinit
      xorg.xwininfo
      xorg.xkill
      mpv
    ];
    home.keyboard = {
      layout = "fr";
      options = ["caps:escape"];
    };
    home.file.".xmonad/xmobarrc".source = ./conf/xmobarrc;
    home.file.".config/ncmpcpp" = {
      source = ./conf/ncmpcpp;
      recursive = true;
    };
    home.file.".xmonad/scripts" = {
      source = ./conf/scripts;
      recursive = true;
    };

    programs.firefox = {
      enable = true;
      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        keepassxc-browser
	    ublock-origin
	    umatrix
	    cookie-autodelete
	    dark-night-mode
      ];
    };

    programs.rofi = {
      enable = true;
      theme = "gruvbox-dark";
      terminal = "urxvt";
    };
    
    programs.urxvt = {
      enable = true;
      fonts = ["xft:monospace:size=11:antialias=true"];
      scroll = {
        bar.enable = false;
        lines = 65535;
      };
      extraConfig = {
        "background" =     "rgba:28ff/28ff/28ff/cf00";
        "foreground" =     "#ebdbb2";
        "color0" =         "#282828";
        "color8" =         "#928374";
        "color1" =         "#cc241d";
        "color9" =         "#fb4934";
        "color2" =         "#98971a";
        "color10" =        "#b8bb26";
        "color3" =         "#d79921";
        "color11" =        "#fabd2f";
        "color4" =         "#458588";
        "color12" =        "#83a598";
        "color5" =         "#b16286";
        "color13" =        "#d3869b";
        "color6" =         "#689d6a";
        "color14" =        "#8ec07c";
        "color7" =         "#a89984";
        "color15" =        "#ebdbb2";
        "termName" =       "rxvt-256color";
        "letterSpace" =    "-1";
        "internalBorder" = "10";
        "depth" =          "32";
      };
    };
    programs.neovim = {
      enable = true;
      vimAlias = true;
      plugins = with pkgs; [
        vimPlugins.gruvbox-community
	    vimPlugins.vim-airline
	    vimPlugins.vim-airline-themes
	    vimPlugins.vim-gitgutter
	    vimPlugins.nerdtree
	    vimPlugins.nerdtree-git-plugin
	    vimPlugins.ctrlp-vim
	    vimPlugins.tabular
      ];
      extraConfig = ''
        let g:gruvbox_italic=1
        colorscheme gruvbox
        set background=dark
        let g:airline_powerline_fonts = 1
        autocmd VimEnter * hi Normal ctermbg=NONE guibg=NONE

        "Toggle NERDTree with Ctrl-N
        map <C-n> :NERDTreeToggle<CR>

        "Show hidden files in NERDTree
        let NERDTreeShowHidden=1

        set number relativenumber

        " Run xrdb whenever Xdefaults or Xresources are updated.
        autocmd BufWritePost ~/.Xresources,~/.Xdefaults !xrdb %
      '';
    };
    programs.broot = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };
    programs.zsh = {
      enable = true;
      history = {
        save = 10000;
	    size = 10000;
      };
      enableAutosuggestions = true;
      initExtra = ''
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search

        [[ -n "$key[Up]"   ]] && bindkey -- "$key[Up]"   up-line-or-beginning-search
        [[ -n "$key[Down]" ]] && bindkey -- "$key[Down]" down-line-or-beginning-search
      '';
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
        ];
        theme = "robbyrussell";
      };
      plugins = [ 
        {
	  name = "zsh-syntax-highlighting";
	  file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
	  src = "${pkgs.zsh-syntax-highlighting}";
        }
      ];
    };
    programs.command-not-found.enable = true;
    services.compton.enable = true;
    services.stalonetray = {
      enable = true;
      config = {
        geometry = "1x1-50+0";
        background = "#000000";
	    transparent = true;
	    grow_gravity = "E";
	    icon_gravity = "NE";
	    icon_size = "20";
      };
    };
    services.unclutter.enable = true;
    services.pasystray.enable = true;
    services.mpd = {
      enable = true;
      musicDirectory = "${config.home.homeDirectory}/Nextcloud/Media/Music";
    };
    services.dunst = {
      enable = true;
      settings = {
        global = {
	      monitor = 0;
          geometry = "350x5-30+50";
          transparency = 10;
          font = "monospace 14";
	      idle_threshold = 120;
	      allow_markup = "yes";
	      format = "<b>%s</b>\n%b";
	      show_age_threshold = 300;
	      word_wrap = "yes";
	      sticky_history = "yes";
	      sort = "yes";
        };
	frame = {
      width = 3;
	  color = "#ebdbb2";
	};
    shortcuts = {
      close = "ctrl+space";
	  close_all = "ctrl+shift+space";
	  history = "ctrl+grave";
	  context = "ctrl+shift+period";
	};
	urgency_low = {
	  foreground = "#ebdbb2";
	  background = "#32302f";
	  timeout = 10;
	};
	urgency_normal = {
	  foreground = "#ebdbb2";
	  background = "#32302f";
	  timeout = 10;
	};
	urgency_critical = {
	  foreground = "#ebdbb2";
	  background = "#32302f";
	  timeout = 10;
	};
      };
    };
    services.nextcloud-client.enable = true;
    services.gpg-agent = { enable = true; enableSshSupport = true; };
    services.gnome-keyring = {
      enable = true;
      components = ["pkcs11" "secrets"];
    };
  };

  system.stateVersion = "19.09";
}

