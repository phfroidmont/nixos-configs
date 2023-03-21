{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editor.emacs;
in {
  options.modules.editor.emacs = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      imports = [ inputs.nix-doom-emacs.hmModule ];

      home.packages = with pkgs.unstable; [
        ripgrep
        fd
        findutils.locate

        metals
        rnix-lsp
        nixfmt
      ];

      services.emacs = {
        enable = true;
        client.enable = true;
      };

      programs.doom-emacs = {
        enable = true;
        doomPrivateDir = ./doom.d;
        emacsPackagesOverlay = final: prev: {
          ob-ammonite = with final;
            (trivialBuild {
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
    };
  };
}
