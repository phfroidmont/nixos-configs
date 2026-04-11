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

              bindkey "^P" up-line-or-beginning-search
              bindkey "^N" down-line-or-beginning-search

              _aegis_vpn() {
                local -a subcmds servers
                local output

                subcmds=(up down status list switch)

                if (( CURRENT == 2 )); then
                  _describe 'aegis-vpn command' subcmds
                  return
                fi

                if [[ "''${words[2]}" != "switch" ]]; then
                  return
                fi

                output="$(${pkgs.coreutils}/bin/timeout 1s aegis-vpn list 2>/dev/null || true)"
                if [[ -z "$output" ]]; then
                  return
                fi

                servers=("''${(@f)$(${pkgs.coreutils}/bin/printf '%s\n' "$output" | ${pkgs.gnused}/bin/sed -E 's/^[*[:space:]]+//')}")
                if (( ''${#servers[@]} > 0 )); then
                  _describe 'mullvad server' servers
                fi
              }
              compdef _aegis_vpn aegis-vpn
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
        pay-respects = {
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
