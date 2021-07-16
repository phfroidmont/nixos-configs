{ pkgs, ... }:
{
  enable = true;
  history = {
    save = 50000;
    size = 50000;
  };
  enableAutosuggestions = true;
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
}
