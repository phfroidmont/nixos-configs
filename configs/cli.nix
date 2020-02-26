{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh-syntax-highlighting
    ranger
    linuxPackages.perf
  ];
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
  };
  programs.command-not-found.enable = true;
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
  home.file.".config/ranger" = {
    source = ./files/ranger;
    recursive = true;
  };
  home.file.".config/ranger/plugins" = {
    source = builtins.fetchGit {
        url = "git://github.com/alexanderjeurissen/ranger_devicons.git";
        rev = "1fa1d0f29047979b9ffd541eb330756ac4b348ab";
    };
    recursive = true;
  };
}
