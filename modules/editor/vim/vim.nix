{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.editor.vim;
in
{
  options.modules.editor.vim = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      imports = [ inputs.nixvim.homeManagerModules.nixvim ];

      programs.neovim = {
        enable = true;
        package = pkgs.neovim-unwrapped;
        vimAlias = true;
        vimdiffAlias = true;
        withNodeJs = true;
        plugins =
          (with pkgs.vimPlugins; [
            # base distro
            LazyVim
            conform-nvim
            nvim-lint
            markdown-preview-nvim
            render-markdown-nvim

            # theme
            gruvbox-nvim

            # UI
            bufferline-nvim
            gitsigns-nvim
            neogit
            diffview-nvim
            edgy-nvim
            dashboard-nvim
            toggleterm-nvim
            trouble-nvim
            lualine-nvim
            which-key-nvim
            nvim-web-devicons
            mini-nvim
            noice-nvim
            nui-nvim
            nvim-notify
            nvim-lsp-notify
            neo-tree-nvim
            nvim-navic
            dressing-nvim
            aerial-nvim

            # project management
            project-nvim
            neoconf-nvim
            persistence-nvim

            # smart typing
            indent-blankline-nvim
            guess-indent-nvim
            vim-illuminate

            # LSP
            nvim-lspconfig
            nvim-lightbulb # lightbulb for quick actions
            # nvim-code-action-menu # code action menu
            neodev-nvim
            SchemaStore-nvim # load known formats for json and yaml
            nvim-metals

            # cmp plugins
            nvim-cmp # completion plugin
            cmp-buffer # buffer completions
            cmp-path # path completions
            cmp_luasnip # snipper completions
            cmp-nvim-lsp # LSP completions

            # snippets
            luasnip # snippet engine
            nvim-snippets
            friendly-snippets # a bunch of snippets to use

            # search functionality
            plenary-nvim
            telescope-nvim
            telescope-fzf-native-nvim
            grug-far-nvim
            flash-nvim

            # treesitter
            nvim-treesitter-context
            nvim-ts-autotag
            nvim-treesitter-textobjects
            nvim-treesitter.withAllGrammars

            # comments
            ts-comments-nvim
            nvim-ts-context-commentstring
            todo-comments-nvim

            # leap
            vim-repeat
            leap-nvim
            flit-nvim

            # DAP
            nvim-dap
            nvim-dap-ui
            nvim-dap-virtual-text

            # neotest
            neotest
            neotest-rust

            # SQL
            vim-dadbod
            vim-dadbod-ui
            vim-dadbod-completion

            lazy-nvim
            lazydev-nvim
            vim-startuptime
          ])
          ++ [
            # File manager
            (pkgs.vimUtils.buildVimPlugin {
              name = "yazi.nvim";
              src = inputs.vim-yazi;
            })
          ];

        extraPackages = with pkgs; [
          gcc # needed for nvim-treesitter

          # HTML, CSS, JSON
          vscode-langservers-extracted

          # Nix
          nixd
          statix
          nixfmt-rfc-style

          # SQL
          sqlfluff

          # LazyVim defaults
          stylua
          shfmt

          # Markdown extra
          markdownlint-cli2
          marksman

          # Docker extra
          nodePackages.dockerfile-language-server-nodejs
          hadolint
          docker-compose-language-service

          # JSON and YAML extras
          nodePackages.yaml-language-server

          # Custom
          editorconfig-checker
          shellcheck
        ];

        extraLuaConfig = # lua
          ''
            require("gruvbox").setup({
               overrides = {
                 Include = { ["link"] = "GruvboxRed" },
                 ["@constructor"] = { ["link"] = "GruvboxYellow" },
                 ["@function.builtin"] = { ["link"] = "GruvboxFg1" },
                 ["@function.call"] = { ["link"] = "GruvboxFg1" },
                 ["@function.macro"] = { ["link"] = "GruvboxFg1" },
                 ["@function.method.call.scala"] = { ["link"] = "GruvboxFg1" },
                 ["@method.call"] = { ["link"] = "GruvboxFg1" },
                 ["@variable.member.scala"] = { ["link"] = "GruvboxFg1" },
                 ["@lsp.type.type.scala"] = { ["link"] = "" },
                 ["@lsp.type.method.scala"] = { ["link"] = "" },
                 ["@lsp.type.modifier.scala"] = { ["link"] = "GruvboxOrange" },
                 ["@lsp.type.typeParameter.scala"] = { ["link"] = "GruvboxAqua" },
                 ["@lsp.type.type.nix"] = { ["link"] = "" },
                 ["@lsp.type.method.nix"] = { ["link"] = "" },
                 ["@lsp.type.macro.nix"] = { ["link"] = "" },
                 ["@lsp.type.interface.nix"] = { ["link"] = "" },
               },
            })

            require("lazy").setup({
              spec = {
                { "LazyVim/LazyVim", import = "lazyvim.plugins" },
                -- import any extras modules here
                { import = "lazyvim.plugins.extras.dap.core" },
                { import = "lazyvim.plugins.extras.dap.nlua" },
                { import = "lazyvim.plugins.extras.ui.edgy" },
                { import = "lazyvim.plugins.extras.coding.mini-comment" },
                { import = "lazyvim.plugins.extras.editor.aerial" },
                { import = "lazyvim.plugins.extras.editor.leap" },
                { import = "lazyvim.plugins.extras.editor.navic" },
                { import = "lazyvim.plugins.extras.formatting.prettier" },
                { import = "lazyvim.plugins.extras.lang.angular" },
                { import = "lazyvim.plugins.extras.lang.docker" },
                { import = "lazyvim.plugins.extras.lang.json" },
                { import = "lazyvim.plugins.extras.lang.markdown" },
                { import = "lazyvim.plugins.extras.lang.sql" },
                { import = "lazyvim.plugins.extras.lang.yaml" },
                { import = "lazyvim.plugins.extras.lang.scala" },
                { import = "lazyvim.plugins.extras.lang.typescript" },
                { import = "lazyvim.plugins.extras.test.core" },
                -- import/override with your plugins
                { import = "plugins" },
              },
              defaults = {
                -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
                -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
                lazy = false,
                -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
                -- have outdated releases, which may break your Neovim install.
                version = false, -- always use the latest git commit
                -- version = "*", -- try installing the latest stable version for plugins that support semver
              },
              performance = {
                -- Used for NixOS
                reset_packpath = false,
                rtp = {
                    reset = false,
                    -- disable some rtp plugins
                    disabled_plugins = {
                      "gzip",
                      -- "matchit",
                      -- "matchparen",
                      -- "netrwPlugin",
                      "tarPlugin",
                      "tohtml",
                      "tutor",
                      "zipPlugin",
                    },
                  }
                },
              dev = {
                path = "${
                  pkgs.vimUtils.packDir
                    config.home-manager.users.${config.user.name}.programs.neovim.finalPackage.passthru.packpathDirs
                }/pack/myNeovimPackages/start",
                patterns = {"folke", "nvim-telescope", "hrsh7th", "akinsho", "stevearc", "LazyVim", "catppuccin", "saadparwaiz1", "nvimdev", "rafamadriz", "lewis6991", "lukas-reineke", "nvim-lualine", "L3MON4D3", "williamboman", "echasnovski", "nvim-neo-tree", "MunifTanjim", "mfussenegger", "rcarriga", "neovim", "nvim-pack", "nvim-treesitter", "windwp", "JoosepAlviste", "nvim-tree", "nvim-lua", "RRethy", "dstein64", "Saecki", "ggandor", "iamcco", "nvim-neotest", "rouge8", "theHamsta", "SmiteshP", "jbyuki", "simrat39", "b0o", "tpope", "kosayoda", "ellisonleao", "NeogitOrg", "sindrets", "scalameta", "garymjr", "mikavilpas","kristijanhusak","MagicDuck","MeanderingProgrammer"},
              },
              install = {
                missing = false,
              },
            })
          '';
      };

      xdg.configFile."nvim/lua" = {
        recursive = true;
        source = ./lua;
      };

      programs.nixvim = {
        enable = false;
        package = pkgs.neovim-unwrapped;
        vimAlias = true;

        keymaps = [
          # Search
          {
            key = "<leader>cx";
            action = "<CMD>Telescope diagnostics layout_strategy=vertical<CR>";
            options.desc = "Search diagnostics";
          }
          # Project
          {
            key = "<leader>ps";
            action = "<CMD>wa<CR>";
            options.desc = "Save all buffers";
          }
        ];

        plugins = {
          lazy = {
            enable = true;
            plugins = [
              {
                pkg = pkgs.vimPlugins.gitsigns-nvim;
                opts.__raw = # lua
                  ''
                    {
                      on_attach = function(buffer)
                        local gs = package.loaded.gitsigns

                        local function map(mode, l ,r, desc)
                          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc})
                        end

                        map("n", "<leader>g;", function()
                          if vim.wo.diff then
                            vim.cmd.normal({ "]c", bang = true })
                          else
                            gs.nav_hunk("next")
                          end
                        end, "Next Hunk")
                        map("n", "<leader>g,", function()
                          if vim.wo.diff then
                            vim.cmd.normal({ "[c", bang = true })
                          else
                            gs.nav_hunk("prev")
                          end
                        end, "Prev Hunk")
                        map({ "n", "v" }, "<leader>gs", gs.stage_hunk, "Stage Hunk")
                        map({ "n", "v" }, "<leader>gr", gs.reset_hunk, "Reset Hunk")
                        map("n", "<leader>gS", gs.stage_buffer, "Stage Buffer")
                        map("n", "<leader>gu", gs.undo_stage_hunk, "Undo Stage Hunk")
                        map("n", "<leader>gR", gs.reset_buffer, "Reset Buffer")
                        map("n", "<leader>gp", gs.preview_hunk_inline, "Preview Hunk Inline")
                        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame Line")
                        map("n", "<leader>gd", gs.diffthis, "Diff This")
                        map("n", "<leader>gD", function() gs.diffthis("~") end, "Diff This ~")
                        map('n', '<leader>tb', gs.toggle_current_line_blame, "Toggle current line blame")
                        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
                      end,
                    }
                  '';
              }
              {
                pkg = pkgs.vimPlugins.which-key-nvim;
                event = "VimEnter";
                config = # lua
                  ''
                    function ()
                      require('which-key').setup()
                      require('which-key').register {
                        ['<leader>b'] = { name = 'Buffer', _ = 'which_key_ignore' },
                        ['<leader>c'] = { name = 'Code', _ = 'which_key_ignore' },
                        ['<leader>d'] = { name = 'Document', _ = 'which_key_ignore' },
                        ['<leader>f'] = { name = 'File', _ = 'which_key_ignore' },
                        ['<leader>g'] = { name = 'Git', _ = 'which_key_ignore' },
                        ['<leader>o'] = { name = 'Org', _ = 'which_key_ignore' },
                        ['<leader>n'] = { name = 'Org-roam', _ = 'which_key_ignore' },
                        ['<leader>p'] = { name = 'Project', _ = 'which_key_ignore' },
                        ['<leader>r'] = { name = 'Rename', _ = 'which_key_ignore' },
                        ['<leader>s'] = { name = 'Search', _ = 'which_key_ignore' },
                        ['<leader>w'] = { name = 'Window', _ = 'which_key_ignore' },
                        ['<leader>t'] = { name = 'Toggle', _ = 'which_key_ignore' },
                        ['<leader>q'] = { name = 'Quit/Session', _ = 'which_key_ignore' },
                      }
                    end
                  '';
              }
              {
                pkg = pkgs.vimPlugins.nvim-lspconfig;
                config = # lua
                  ''
                    function ()
                      vim.api.nvim_create_autocmd('LspAttach', {
                        group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
                        callback = function(event)
                          local map = function(keys, func, desc)
                            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                          end

                          map('gd', require('telescope.builtin').lsp_definitions, 'Go to definition')
                          map('gr', require('telescope.builtin').lsp_references, 'Go to references')
                          map('gI', require('telescope.builtin').lsp_implementations, 'Goto implementation')
                          map('gD', vim.lsp.buf.declaration, 'Go to declaration')
                          map('gT', require('telescope.builtin').lsp_type_definitions, 'Type definition')
                          map('<leader>cD', require('telescope.builtin').lsp_document_symbols, 'Document symbols')
                          map('<leader>cw', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Workspace symbols ')
                          map('<leader>cd', vim.diagnostic.open_float, 'Line diagnostics')
                          map('<leader>c,', vim.diagnostic.goto_prev, 'Previous diagnostics')
                          map('<leader>c;', vim.diagnostic.goto_next, 'Next diagnostics')
                          map('<leader>cr', vim.lsp.buf.rename, 'Rename')
                          map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
                          map('K', vim.lsp.buf.hover, 'Hover Documentation')
                        end
                      })

                      local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
                      local capabilities = vim.tbl_deep_extend(
                        "force",
                        {},
                        vim.lsp.protocol.make_client_capabilities(),
                        has_cmp and cmp_nvim_lsp.default_capabilities() or {}
                      )

                      local function setup(server, server_opts)
                        local server_opts_with_caps = vim.tbl_deep_extend("force", {
                          capabilities = vim.deepcopy(capabilities),
                        }, server_opts)

                        require("lspconfig")[server].setup(server_opts_with_caps)
                      end

                      setup("yamlls", {})
                      setup("typos_lsp", {
                        init_options = { diagnosticSeverity = "Hint" }
                      })
                      setup("tsserver", {})
                      setup("terraformls", {})
                      setup("marksman", {})
                      setup("lua_ls", {})
                      setup("jsonls", { cmd = { "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server", "--stdio" } })
                      setup("html", { cmd = { "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server", "--stdio" } })
                      setup("eslint", { cmd = { "${pkgs.vscode-langservers-extracted}/bin/vscode-eslint-language-server", "--stdio" } })
                      setup("dockerls", { cmd = { "${pkgs.dockerfile-language-server-nodejs}/bin/docker-langserver", "--stdio" } })
                      setup("docker_compose_language_service", {})
                      setup("cssls", { cmd = { "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server", "--stdio" } })
                      setup("bashls", {})
                      setup("ansiblels", { cmd = { "${pkgs.ansible-language-server}/bin/ansible-language-server", "--stdio" } })
                    end
                  '';
              }
              {
                pkg = pkgs.vimPlugins.nvim-cmp;
                event = "InsertEnter";
                dependencies = [
                  pkgs.vimPlugins.cmp-nvim-lsp
                  pkgs.vimPlugins.cmp-path
                  pkgs.vimPlugins.cmp-buffer
                ];
                opts.__raw = # lua
                  ''
                    function()
                      local cmp = require("cmp")
                      return {
                        mapping = {
                            ["<C-Space>"] = cmp.mapping.complete(),
                            ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                            ["<C-e>"] = cmp.mapping.close(),
                            ["<C-f>"] = cmp.mapping.scroll_docs(4),
                            ["<CR>"] = cmp.mapping.confirm({ select = true }),
                            ["<C-y>"] = cmp.mapping.confirm({ select = true }),
                            ["<S-Tab>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "s" }),
                            ["<Tab>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "s" }),
                        },
                        sources = {
                          { name = "nvim_lsp" },
                          { name = "path" },
                          { name = "buffer" },
                          { name = "orgmode" },
                        },
                      }
                    end
                  '';
              }

              # Disabled for now as it tries to write org grammar to its own directory in the nix store
              # https://github.com/nvim-orgmode/orgmode/blob/95fb795a422f0455e03d13a3f83525f1d00793ad/lua/orgmode/utils/treesitter/install.lua#L9
              # {
              #   pkg = pkgs.vimPlugins.orgmode;
              #   event = "VeryLazy";
              #   ft = [ "org" ];
              #   config = /*lua*/ ''
              #     function ()
              #       require('orgmode').setup({
              #         org_agend_files = '~/Nextcloud/Org/**/*',
              #         org_default_notes_file = '~/Nextcloud/Org/refile.org',
              #       })
              #     end
              #   '';
              # }
              # {
              #   pkg = (pkgs.vimUtils.buildVimPlugin {
              #     name = "org-roam.nvim";
              #     src = inputs.vim-org-roam;
              #   });
              #   dependencies = [ pkgs.vimPlugins.orgmode ];
              #   event = "VeryLazy";
              #   ft = [ "org" ];
              #   config = /*lua*/ ''
              #     function ()
              #       require('org-roam').setup({
              #         directory = '~/Nextcloud/OrgRoam',
              #       })
              #     end
              #   '';
              # }
            ];
          };
        };
      };

      home.packages = with pkgs; [
        ripgrep
        fd
        nodejs
        opentofu
        coursier

        # LSP
        yaml-language-server
        typos-lsp
        nodePackages.typescript-language-server
        nodePackages.prettier
        terraform-ls
        sqls
        nixd
        marksman
        lua-language-server
        docker-compose-language-service
        bash-language-server
        inputs.nixpkgs-master.legacyPackages.x86_64-linux.angular-language-server
        inputs.nixpkgs-master.legacyPackages.x86_64-linux.vtsls
      ];
    };
  };
}
