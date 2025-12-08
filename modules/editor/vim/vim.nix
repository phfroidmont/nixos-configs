{
  inputs,
  config,
  lib,
  pkgs,
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
    home-manager.users.${config.user.name} =
      { config, ... }:
      {

        programs.neovim = {
          enable = true;
          package = pkgs.neovim-unwrapped;
          vimAlias = true;
          vimdiffAlias = true;
          withNodeJs = true;
          plugins = with pkgs.vimPlugins; [
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
            mini-ai
            mini-comment
            mini-icons
            mini-pairs
            noice-nvim
            nui-nvim
            nvim-notify
            nvim-lsp-notify
            neo-tree-nvim
            nvim-navic
            dressing-nvim
            aerial-nvim
            snacks-nvim

            # project management
            project-nvim
            neoconf-nvim
            persistence-nvim

            # smart typing
            guess-indent-nvim
            vim-illuminate

            # LSP
            nvim-lspconfig
            nvim-lightbulb # lightbulb for quick actions
            # nvim-code-action-menu # code action menu
            neodev-nvim
            SchemaStore-nvim # load known formats for json and yaml
            nvim-metals
            nvim-jdtls

            # cmp plugins
            nvim-cmp
            blink-cmp # completion plugin
            cmp_luasnip # snipper completions

            # snippets
            luasnip # snippet engine
            friendly-snippets # a bunch of snippets to use

            # search functionality
            plenary-nvim
            telescope-nvim
            telescope-fzf-native-nvim
            fzf-lua
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
            one-small-step-for-vimkind

            # neotest
            neotest
            neotest-rust
            neotest-elixir

            # SQL
            vim-dadbod
            vim-dadbod-ui
            vim-dadbod-completion

            lazy-nvim
            lazydev-nvim
            vim-startuptime
            yazi-nvim
            zk-nvim
            avante-nvim
            blink-cmp-avante
            img-clip-nvim

            (pkgs.vimUtils.buildVimPlugin {
              pname = "opencode.nvim";
              version = "2025-12-04";
              src = pkgs.fetchFromGitHub {
                owner = "NickvanDyke";
                repo = "opencode.nvim";
                rev = "963fad75f794deb85d1c310d2e2cb033da44f670";
                hash = "sha256-nKOsHgMptHnOS+SCTHa77sQ/ZiUY0aW26I8GN7ocRHE=";
              };
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
            dockerfile-language-server
            hadolint
            docker-compose-language-service

            # JSON and YAML extras
            nodePackages.yaml-language-server

            # Java
            jdt-language-server

            # Elixir
            beam28Packages.elixir-ls

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
                  { import = "lazyvim.plugins.extras.lang.java" },
                  { import = "lazyvim.plugins.extras.lang.json" },
                  { import = "lazyvim.plugins.extras.lang.markdown" },
                  { import = "lazyvim.plugins.extras.lang.sql" },
                  { import = "lazyvim.plugins.extras.lang.yaml" },
                  { import = "lazyvim.plugins.extras.lang.scala" },
                  { import = "lazyvim.plugins.extras.lang.elixir" },
                  { import = "lazyvim.plugins.extras.test.core" },
                  { import = "lazyvim.plugins.extras.lang.typescript" },
                  { import = "lazyvim.plugins.extras.ai.avante" },
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
                  path = "${pkgs.vimUtils.packDir config.programs.neovim.finalPackage.passthru.packpathDirs}/pack/myNeovimPackages/start",
                  patterns = {""},
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

        home.sessionVariables = {
          ZK_NOTEBOOK_DIR = "${config.home.homeDirectory}/Nextcloud/notes";
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
          angular-language-server
          vtsls
          zk

          inputs.llm-agents.packages.${pkgs.system}.opencode
        ];
      };
  };
}
