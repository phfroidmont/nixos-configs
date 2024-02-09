{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.editor.emacs;
  myEmacs = pkgs.unstable.emacs29.override {
    withNativeCompilation = true;
    withSQLite3 = true;
    withTreeSitter = true;
    withWebP = true;
  };
  myEmacsWithPackages = myEmacs.pkgs.withPackages
    (epkgs: with epkgs; [ vterm pdf-tools treesit-grammars.with-all-grammars ]);
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
        nixfmt # nix formatter
        shfmt # sh formatter
        shellcheck # sh linter
        html-tidy # HTML formatter
        nodePackages.stylelint # CSS linter
        nodePackages.js-beautify # JS/CSS/HTML formatter

        # LSPs
        coursier
        # metals # Scala
        rnix-lsp # Nix
        phpactor # PHP
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
        poppler_utils
        gnutar
        unzip
      ];

      services.emacs = {
        enable = true;
        client.enable = true;
        package = myEmacsWithPackages;
      };

      # Use either this or nix-doom-emacs
      programs.emacs = {
        enable = true;
        package = myEmacs;
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

      # imports = [ inputs.nix-doom-emacs.hmModule ];
      # programs.doom-emacs = {
      #   enable = true;
      #   doomPrivateDir = ./doom.d;
      #   emacsPackagesOverlay = final: prev: {
      #     ob-ammonite = with final;
      #       (trivialBuild {
      #         src = pkgs.fetchFromGitHub {
      #           owner = "zwild";
      #           repo = "ob-ammonite";
      #           rev = "39937dff395e70aff76a4224fa49cf2ec6c57cca";
      #           sha256 = pkgs.lib.fakeSha256;
      #         };
      #         pname = "ob-ammonite";
      #         packageRequires = [ s dash editorconfig ];
      #       });
      #   };
      # };
    };
  };
}
