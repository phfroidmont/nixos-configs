{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.zsh;
in
{
  options.modules.desktop.zsh = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {

    environment.pathsToLink = [ "/share/zsh" ];

    programs.zsh.enable = true;

    users.users.${config.user.name} = {
      shell = pkgs.zsh;
    };

    home-manager.users.${config.user.name} = {
      programs = {
        zsh = {
          enable = true;
          history = {
            save = 50000;
            size = 50000;
          };
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          initContent = # bash
            ''
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
              "terraform"
              "systemd"
            ];
          };
          plugins = [
            {
              name = "nix-zsh-completions";
              src = pkgs.nix-zsh-completions;
            }
            {
              name = "zsh-completions";
              src = pkgs.zsh-completions;
            }
          ];
        };
        thefuck = {
          enable = true;
          enableZshIntegration = true;
        };
        starship = {
          enable = true;
          enableZshIntegration = true;
          settings = {
            add_newline = true;
            cmd_duration = {
              min_time = 0;
              show_milliseconds = true;
            };
            scala = {
              symbol = " ";
            };
            terraform = {
              symbol = "󱁢 ";
            };
            nix_shell = {
              symbol = "󱄅 ";
            };
            nodejs = {
              symbol = " ";
            };
            php = {
              symbol = " ";
            };
          };
        };
      };
    };
  };
}
