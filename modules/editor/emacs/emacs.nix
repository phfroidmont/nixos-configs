{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.editor.emacs;
in
{
  options.modules.editor.emacs = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

      home = {
        packages = [
          pkgs.binutils
          pkgs.ripgrep
          pkgs.fd
          pkgs.findutils.locate
          pkgs.python311
          pkgs.libsecret
          pkgs.gcc
          pkgs.gnumake
          pkgs.cmake
          pkgs.nodejs

          pkgs.opentofu
          pkgs.pandoc

          # Formatters and linters
          pkgs.nixfmt-rfc-style # nix formatter
          pkgs.nixpkgs-fmt
          pkgs.shfmt # sh formatter
          pkgs.shellcheck # sh linter
          pkgs.html-tidy # HTML formatter
          pkgs.nodePackages.stylelint # CSS linter
          pkgs.nodePackages.js-beautify # JS/CSS/HTML formatter

          # LSPs
          pkgs.coursier
          # metals # Scala

          # Nix
          pkgs.nil

          pkgs.phpactor # PHP
          #OCaml
          pkgs.ocaml
          pkgs.dune_3
          pkgs.ocamlPackages.ocaml-lsp
          pkgs.ocamlPackages.ocamlformat
          pkgs.ocamlPackages.utop
          pkgs.ocamlPackages.ocp-indent
          pkgs.ocamlPackages.merlin

          # Used by org-roam
          pkgs.sqlite
          pkgs.graphviz

          # Used by elfeed-tube
          pkgs.yt-dlp
          pkgs.mpv

          # Used by dirvish
          pkgs.imagemagick
          pkgs.ffmpegthumbnailer
          pkgs.mediainfo
          pkgs.poppler
          pkgs.gnutar
          pkgs.unzip
        ];
        sessionPath = [ "${config.home-manager.users.${config.user.name}.xdg.configHome}/emacs/bin" ];
        activation = {
          installDoomEmacs = ''
            if [ ! -d "${config.home-manager.users.${config.user.name}.xdg.configHome}/emacs" ]; then
               git clone --depth=1 --single-branch https://github.com/doomemacs/doomemacs "${
                 config.home-manager.users.${config.user.name}.xdg.configHome
               }/emacs"
            fi
          '';
        };
      };

      services.emacs = {
        enable = true;
        client.enable = true;
      };

      programs.emacs = {
        enable = true;
        package = pkgs.emacs30.override {
          withNativeCompilation = true;
          withPgtk = true;
          withSQLite3 = true;
          withTreeSitter = true;
          withWebP = true;
        };
        extraPackages =
          epkgs: with epkgs; [
            vterm
            pdf-tools
            treesit-grammars.with-all-grammars
          ];
      };
      xdg.configFile = {
        "doom" = {
          source = ./doom.d;
        };
      };
    };
  };
}
