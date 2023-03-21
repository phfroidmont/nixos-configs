{ config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.editor.vim;
in {
  options.modules.editor.vim = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
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
          set ignorecase

          vnoremap . :norm.<CR>
        '';
      };
    };
  };
}
