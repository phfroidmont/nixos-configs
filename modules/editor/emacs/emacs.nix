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
          pkgs.unstable.binutils
          pkgs.unstable.ripgrep
          pkgs.unstable.fd
          pkgs.unstable.findutils.locate
          pkgs.unstable.python311
          pkgs.unstable.libsecret
          pkgs.unstable.gcc
          pkgs.unstable.gnumake
          pkgs.unstable.cmake
          pkgs.unstable.nodejs

          pkgs.unstable.opentofu
          pkgs.unstable.pandoc

          # Formatters and linters
          pkgs.unstable.nixfmt-rfc-style # nix formatter
          pkgs.unstable.nixpkgs-fmt
          pkgs.unstable.shfmt # sh formatter
          pkgs.unstable.shellcheck # sh linter
          pkgs.unstable.html-tidy # HTML formatter
          pkgs.unstable.nodePackages.stylelint # CSS linter
          pkgs.unstable.nodePackages.js-beautify # JS/CSS/HTML formatter

          # LSPs
          pkgs.unstable.coursier
          # metals # Scala

          # Nix
          pkgs.unstable.nil

          pkgs.phpactor # PHP
          #OCaml
          pkgs.unstable.ocaml
          pkgs.unstable.dune_3
          pkgs.unstable.ocamlPackages.ocaml-lsp
          pkgs.unstable.ocamlPackages.ocamlformat
          pkgs.unstable.ocamlPackages.utop
          pkgs.unstable.ocamlPackages.ocp-indent
          pkgs.unstable.ocamlPackages.merlin

          # Used by org-roam
          pkgs.unstable.sqlite
          pkgs.unstable.graphviz

          # Used by elfeed-tube
          pkgs.unstable.yt-dlp
          pkgs.unstable.mpv

          # Used by dirvish
          pkgs.unstable.imagemagick
          pkgs.unstable.ffmpegthumbnailer
          pkgs.unstable.mediainfo
          pkgs.unstable.poppler
          pkgs.unstable.gnutar
          pkgs.unstable.unzip
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
        package = pkgs.unstable.emacs29.override {
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
