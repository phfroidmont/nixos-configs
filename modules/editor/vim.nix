{ config, lib, pkgs, inputs, ... }:

let cfg = config.modules.editor.vim;
in {
  options.modules.editor.vim = { enable = lib.my.mkBoolOpt false; };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      imports = [ inputs.nixvim.homeManagerModules.nixvim ];
      programs.nixvim = {
        enable = true;
        package = pkgs.unstable.neovim-unwrapped;
        vimAlias = true;

        globals.mapleader = " ";

        opts = {
          # Keep visual indentation on wrapped lines
          breakindent = true;

          # Hide command line unless needed
          cmdheight = 0;

          # Insert mode completion options
          completeopt = [ "menu" "menuone" "noselect" ];

          # Raise a dialog asking if you wish to save the current file(s)
          confirm = true;

          # Copy previous indentation on autoindenting
          copyindent = true;

          # Highlight current line
          cursorline = true;

          # Enable linematch diff algorithm
          diffopt.__raw = /*lua*/ ''
            vim.list_extend(vim.opt.diffopt:get(), { "algorithm:histogram", "linematch:60" })
          '';

          # Expand <Tab> to spaces
          expandtab = false;

          # Disable `~` on nonexistent lines
          fillchars = { eob = " "; };

          # Enable fold with all code unfolded
          foldcolumn = "1";
          foldenable = true;
          foldlevel = 99;
          foldlevelstart = 99;

          # Ignore case in search patterns
          ignorecase = true;

          # Show substitution preview in split window
          inccommand = "split";
          # Infer casing on word completion
          infercase = true;

          # Global statusline
          laststatus = 3;

          # Wrap lines at 'breakat'
          linebreak = true;

          # Enable list mode
          list = true;

          # Set custom strings for list mode
          # - tabulations are shown as ‒▶
          # - trailing spaces are shown as ·
          # - multiple non-leading consecutive spaces are shown as bullets (·)
          # - non-breakable spaces are shown as ⎕
          listchars = "tab:» ,trail:·,multispace:·,lead: ,nbsp:␣";

          # Enable mouse support
          mouse = "a";

          # Show line numbers
          number = true;

          # Preserve indentation as much as possible
          preserveindent = true;

          # Height of the popup menu
          pumheight = 10;

          # Display line numbers relative to current line
          relativenumber = false;

          # Number of spaces to use for indentation
          shiftwidth = 2;

          # Disable search count wrap and startup messages
          shortmess.__raw = /*lua*/ ''
            vim.tbl_deep_extend("force", vim.opt.shortmess:get(), { s = true, I = true })
          '';

          # Disable showing modes in command line
          showmode = false;

          # Show tabline when needed
          showtabline = 1;

          # Show signs column
          signcolumn = "yes";

          # Override ignorecase if search pattern contains uppercase characters
          smartcase = true;

          # Number of spaces input on <Tab>
          softtabstop = 2;

          # Open horizontal split below (:split)
          splitbelow = true;

          # Open vertical split to the right (:vsplit)
          splitright = true;

          # Number of spaces to represent a <Tab>
          tabstop = 2;

          # Enables 24-bit RGB color
          termguicolors = true;

          # Shorter timeout duration
          timeoutlen = 500;

          # Set window title to the filename
          title = true;

          # Save undo history to undo file (in $XDG_STATE_HOME/nvim/undo)
          undofile = true;

          viewoptions.__raw = /*lua*/ ''
            vim.tbl_filter(function(val) return val ~= "curdir" end, vim.opt.viewoptions:get())
          '';

          # Enable virtual edit in visual block mode
          # This has the effect of selecting empty cells beyond lines boundaries
          virtualedit = "block";

          # Disable line wrapping
          wrap = false;

          # Disable making a backup before overwriting a file
          writebackup = false;

          # Sync clipboard between OS and Neovim.
          clipboard = "unnamedplus";
        };

        keymaps = [
          {
            key = "<leader>sh";
            action = "<CMD>Telescope help_tags<CR>";
            options.desc = "[S]earch [H]elp";
          }
          {
            key = "<leader>sk";
            action = "<CMD>Telescope keymaps<CR>";
            options.desc = "[S]earch [K]eymaps";
          }
          {
            key = "<leader>ss";
            action = "<CMD>Telescope<CR>";
            options.desc = "[S]earch [S]elect Telescope";
          }
          {
            key = "<leader>/";
            action = "<CMD>Telescope live_grep<CR>";
            options.desc = "[S]earch by [G]rep";
          }
          {
            key = "<leader>sr";
            action = "<CMD>Telescope resume<CR>";
            options.desc = "[S]earch [R]esume";
          }
          {
            key = "<leader>.";
            action.__raw = /*lua*/''
              function()
                require("yazi").yazi()
              end
            '';
            options.desc = "Open file manager";
          }
          {
            key = "<leader>cx";
            action = "<CMD>Telescope diagnostics<CR>";
            options.desc = "Search diagnostics";
          }
          {
            key = "<leader>fs";
            action.__raw = /*lua*/''
              function()
                vim.lsp.buf.format()
                vim.cmd.write()
              end
            '';
            options.desc = "Format and save buffer";
          }
          {
            key = "<leader>ps";
            action = "<CMD>wa<CR>";
            options.desc = "Save all buffers";
          }
          {
            key = "<leader>gg";
            action = "<CMD>Neogit<CR>";
          }
          {
            key = "<leader><leader>";
            action = "<CMD>Telescope fd<CR>";
          }
          {
            key = "<leader>bb";
            action = "<CMD>Telescope buffers<CR>";
          }
          {
            key = "<leader>bn";
            action = "<CMD>bnext<CR>";
            options.desc = "Next buffer";
          }
          {
            key = "<leader>bp";
            action = "<CMD>bprev<CR>";
            options.desc = "Previous buffer";
          }
          {
            key = "<leader>bl";
            action = "<CMD>e #<CR>";
            options.desc = "Other buffer";
          }
          {
            key = "<leader>bk";
            action = "<CMD>bdel<CR>";
            options.desc = "Delete buffer";
          }
          {
            key = "<leader>bd";
            action = "<CMD>bdel<CR>";
            options.desc = "Delete buffer";
          }
        ];

        plugins = {
          lualine = {
            enable = true;
          };
          cmp = {
            enable = true;
            settings = {
              sources =
                [
                  { name = "nvim_lsp"; }
                  { name = "path"; }
                  { name = "buffer"; }
                  { name = "cmdline"; }
                ];
              mapping = {
                "<CR>" = "cmp.mapping.confirm({ select = true })";
                "<C-Space>" = "cmp.mapping.complete()";
                "<C-u>" = "cmp.mapping.scroll_docs(-4)";
                "<C-e>" = "cmp.mapping.close()";
                "<C-d>" = "cmp.mapping.scroll_docs(4)";
                "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
                "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
              };
            };
          };
          gitgutter.enable = true;
          leap.enable = true;
          fidget.enable = true;
          neogit = {
            enable = true;
            package = pkgs.unstable.vimPlugins.neogit;
          };
          sleuth.enable = true;
          comment.enable = true;
          direnv.enable = true;
          nix.enable = true;
          treesitter = {
            enable = true;
            indent = true;
            incrementalSelection.enable = true;
            ignoreInstall = [ "org" ];
          };
          telescope = {
            enable = true;
            extensions.fzf-native.enable = true;
            extensions.ui-select.enable = true;
          };
          which-key = {
            enable = true;
            registrations = {
              "<leader>b".name = "[B]uffer";
              "<leader>c".name = "[C]ode";
              "<leader>d".name = "[D]ocument";
              "<leader>f".name = "[F]ile";
              "<leader>g".name = "[G]it";
              "<leader>r".name = "[R]ename";
              "<leader>s".name = "[S]earch";
              "<leader>w".name = "[W]orkspace";
              "<leader>t".name = "[T]oggle";
              "<leader>h".name = "Git [H]unk";
            };
          };
          lsp = {
            enable = true;
            servers = {
              ansiblels.enable = true;
              bashls.enable = true;
              cssls.enable = true;
              docker-compose-language-service.enable = true;
              dockerls.enable = true;
              eslint.enable = true;
              nixd.enable = true;
              html.enable = true;
              lua-ls.enable = true;
              marksman.enable = true;
              sqls.enable = true;
              terraformls.enable = true;
              tsserver.enable = true;
              jsonls.enable = true;
              yamlls.enable = true;
              typos-lsp = {
                enable = true;
                extraOptions.init_options.diagnosticSeverity = "Hint";
              };
            };
            keymaps = {
              silent = true;
              lspBuf = {
                gd = {
                  action = "definition";
                  desc = "Goto Definition";
                };
                gr = {
                  action = "references";
                  desc = "Goto References";
                };
                gD = {
                  action = "declaration";
                  desc = "Goto Declaration";
                };
                gI = {
                  action = "implementation";
                  desc = "Goto Implementation";
                };
                gT = {
                  action = "type_definition";
                  desc = "Type Definition";
                };
                K = {
                  action = "hover";
                  desc = "Hover";
                };
                "<leader>cw" = {
                  action = "workspace_symbol";
                  desc = "Workspace Symbol";
                };
                "<leader>cr" = {
                  action = "rename";
                  desc = "Rename";
                };
              };
              diagnostic = {
                "<leader>cd" = {
                  action = "open_float";
                  desc = "Line Diagnostics";
                };
                "[d" = {
                  action = "goto_next";
                  desc = "Next Diagnostic";
                };
                "]d" = {
                  action = "goto_prev";
                  desc = "Previous Diagnostic";
                };
              };
            };
          };
        };
        extraPlugins = [
          pkgs.unstable.vimPlugins.vim-airline-themes
          pkgs.unstable.vimPlugins.nvim-metals
          (pkgs.vimUtils.buildVimPlugin {
            name = "yazi.nvim";
            src = inputs.vim-yazi;
          })
          pkgs.unstable.vimPlugins.orgmode
          (pkgs.vimUtils.buildVimPlugin {
            name = "org-roam.nvim";
            src = inputs.vim-org-roam;
          })
        ];
        extraConfigLua = /*lua*/
          ''
            require('yazi').setup({
              opts = {
                open_for_directories = true,
              },
            })


            require('orgmode').setup({
              org_agend_files = '~/Nextcloud/Org/**/*',
              org_default_notes_file = '~/Nextcloud/Org/refile.org',
            })
            require('org-roam').setup({
              directory = '~/Nextcloud/OrgRoam',
            })


            local metals_config = require("metals").bare_config()

            metals_config.init_options.statusBarProvider = "off"

            metals_config.settings = {
              showImplicitArguments = true,
            }

            metals_config.on_attach = function(client, bufnr)
              vim.keymap.set(
                "n",
                "<leader>me",
                function() require("telescope").extensions.metals.commands() end,
                { noremap=true, silent=true, buffer = bufn, desc = "Metals commands"}
              )
              vim.keymap.set(
                "n",
                "<leader>co",
                "<CMD>MetalsOrganizeImports<CR>",
                { noremap=true, silent=true, buffer = bufn, desc = "Organize imports"}
              )
            end

            local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
            vim.api.nvim_create_autocmd("FileType", {
              pattern = { "scala", "sbt", "java" },
              callback = function()
                require("metals").initialize_or_attach(metals_config)
              end,
              group = nvim_metals_group,
            })
          '';
        colorschemes.gruvbox = {
          enable = true;
          package = pkgs.unstable.vimPlugins.gruvbox-nvim;
          settings = {
            overrides = {
              Include = { link = "GruvboxRed"; };
              "@constructor" = { link = "GruvboxYellow"; };
              "@function.builtin" = { link = "GruvboxFg1"; };
              "@function.call" = { link = "GruvboxFg1"; };
              "@function.macro" = { link = "GruvboxFg1"; };
              "@function.method.call.scala" = { link = "GruvboxFg1"; };
              "@method.call" = { link = "GruvboxFg1"; };
              "@variable.member.scala" = { link = "GruvboxFg1"; };
              "@lsp.type.type.scala" = { link = ""; };
              "@lsp.type.method.scala" = { link = ""; };
              "@lsp.type.modifier.scala" = { link = "GruvboxOrange"; };
              "@lsp.type.typeParameter.scala" = { link = "GruvboxAqua"; };

              "@lsp.type.type.nix" = { link = ""; };
              "@lsp.type.method.nix" = { link = ""; };
              "@lsp.type.macro.nix" = { link = ""; };
              "@lsp.type.interface.nix" = { link = ""; };
            };
          };
        };
      };

      home.packages = with pkgs.unstable; [
        ripgrep
        fd
        nodejs
        opentofu
        nixfmt-rfc-style
        nixpkgs-fmt
        coursier
        nil
      ];
    };
  };
}
