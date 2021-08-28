{ pkgs, ... }:
{
  enable = true;
  history = {
    save = 50000;
    size = 50000;
  };
  enableCompletion = true;
  enableAutosuggestions = true;
  enableSyntaxHighlighting = true;
  initExtra = ''
    autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search

    [[ -n "$key[Up]"   ]] && bindkey -- "$key[Up]"   up-line-or-beginning-search
    [[ -n "$key[Down]" ]] && bindkey -- "$key[Down]" down-line-or-beginning-search

    eval $(thefuck --alias)
  '';
  oh-my-zsh = {
    enable = true;
    plugins = [
      "git"
      "terraform"
    ];
    theme = "robbyrussell";
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
}
