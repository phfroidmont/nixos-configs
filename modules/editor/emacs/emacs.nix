{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editor.emacs;
in {
  options.modules.editor.emacs = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

      home.packages = with pkgs.unstable; [
        binutils
        ripgrep
        fd
        findutils.locate
        python311
        libsecret
        gcc
        gnumake
        cmake
        nodejs

        opentofu
        pandoc

        # Formatters and linters
        nixfmt-rfc-style # nix formatter
        nixpkgs-fmt
        shfmt # sh formatter
        shellcheck # sh linter
        html-tidy # HTML formatter
        nodePackages.stylelint # CSS linter
        nodePackages.js-beautify # JS/CSS/HTML formatter

        # LSPs
        coursier
        # metals # Scala

        # Nix
        nil

        pkgs.phpactor # PHP
        #OCaml
        ocaml
        dune_3
        ocamlPackages.ocaml-lsp
        ocamlPackages.ocamlformat
        ocamlPackages.utop
        ocamlPackages.ocp-indent
        ocamlPackages.merlin

        # Used by org-roam
        sqlite
        graphviz

        # Used by elfeed-tube
        yt-dlp
        mpv

        # Used by dirvish
        imagemagick
        ffmpegthumbnailer
        mediainfo
        poppler
        gnutar
        unzip
      ];

      services.emacs = {
        enable = true;
        client.enable = true;
      };

      programs.emacs = {
        enable = true;
        package = pkgs.unstable.emacs29.override {
          withNativeCompilation = true;
          withPgtk = true;
          withSQLite3 = true;
          withTreeSitter = true;
          withWebP = true;
        };
        extraPackages = epkgs:
          with epkgs; [
            vterm
            pdf-tools
            treesit-grammars.with-all-grammars
          ];
      };
      xdg.configFile = { "doom" = { source = ./doom.d; }; };
      home.sessionPath = [
        "${
          config.home-manager.users.${config.user.name}.xdg.configHome
        }/emacs/bin"
      ];
      home.activation = {
        installDoomEmacs = ''
          if [ ! -d "${
            config.home-manager.users.${config.user.name}.xdg.configHome
          }/emacs" ]; then
             git clone --depth=1 --single-branch https://github.com/doomemacs/doomemacs "${
               config.home-manager.users.${config.user.name}.xdg.configHome
             }/emacs"
          fi
        '';
      };
    };
  };
}
