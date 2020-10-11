{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh-syntax-highlighting
    ranger
    R
    tldr
    thefuck
    atool
    linuxPackages.perf
    meslo-lg
    nerdfonts
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
  programs.bat.enable = true;
  programs.jq.enable = true;
  programs.fzf.enable = true;
  programs.lesspipe.enable = true;
  programs.zathura.enable = true;
  programs.pazi.enable = true;
  programs.htop = {
    enable = true;
    hideUserlandThreads = true;
    highlightBaseName = true;
    fields = [ "PID" "USER" "M_RESIDENT" "M_SHARE" "STATE" "PERCENT_CPU" "PERCENT_MEM" "IO_RATE" "TIME" "COMM" ];
    meters.left =  [ "LeftCPUs" "Memory" "Swap" ] ;
    meters.right = [ "RightCPUs" "Tasks" "LoadAverage" "Uptime" ];
  };
  programs.broot = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.command-not-found.enable = true;
  programs.zsh = {
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
  };
  home.file.".config/ranger" = {
    source = ./files/ranger;
    recursive = true;
  };
  home.file.".config/ranger/plugins" = {
    source = builtins.fetchGit {
        url = "git://github.com/alexanderjeurissen/ranger_devicons.git";
        rev = "68ffbffd086b0e9bb98c74705abe891b756b9e11";
    };
    recursive = true;
  };
}
