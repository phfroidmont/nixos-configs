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
          # Search
          {
            key = "<leader><leader>";
            action = "<CMD>Telescope fd layout_strategy=vertical<CR>";
          }
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
            action = "<CMD>Telescope live_grep layout_strategy=vertical<CR>";
            options.desc = "Search with rg";
          }
          {
            key = "<leader>sr";
            action = "<CMD>Telescope resume<CR>";
            options.desc = "[S]earch [R]esume";
          }
          {
            key = "<leader>cx";
            action = "<CMD>Telescope diagnostics layout_strategy=vertical<CR>";
            options.desc = "Search diagnostics";
          }
          # File
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
            mode = "n";
            key = "<leader>fn";
            action = "<CMD>enew<CR>";
            options.desc = "New File";
          }
          # Project
          {
            key = "<leader>ps";
            action = "<CMD>wa<CR>";
            options.desc = "Save all buffers";
          }
          # Git
          {
            key = "<leader>gg";
            action = "<CMD>Neogit<CR>";
          }
          # Buffers
          {
            key = "<leader>bb";
            action = "<CMD>Telescope buffers layout_strategy=vertical<CR>";
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
            action = "<CMD>bd<CR>";
            options.desc = "Delete buffer and Window";
          }
          {
            key = "<leader>bd";
            action = "<CMD>bd<CR>";
            options.desc = "Delete buffer and Window";
          }
          # Windows
          {
            mode = "n";
            key = "<leader>ww";
            action = "<C-w>p";
            options = { desc = "Other Window"; remap = true; };
          }
          {
            mode = "n";
            key = "<leader>wd";
            action = "<C-w>c";
            options = { desc = "Delete Window"; remap = true; };
          }
          {
            mode = "n";
            key = "<leader>ws";
            action = "<C-w>s";
            options = { desc = "Split Window Below"; remap = true; };
          }
          {
            mode = "n";
            key = "<leader>wv";
            action = "<C-w>v";
            options = { desc = "Split Window Right"; remap = true; };
          }
          {
            mode = "n";
            key = "<c-j>";
            action = "<C-w>j";
            options = { desc = "Go to Lower Winddow"; remap = true; };
          }
          {
            mode = "n";
            key = "<leader>wj";
            action = "<C-w>j";
            options = { desc = "Go to Lower Winddow"; remap = true; };
          }
          {
            mode = "n";
            key = "<c-k>";
            action = "<C-w>k";
            options = { desc = "Go to Upper Winddow"; remap = true; };
          }
          {
            mode = "n";
            key = "<leader>wk";
            action = "<C-w>k";
            options = { desc = "Go to Upper Winddow"; remap = true; };
          }
          {
            mode = "n";
            key = "<c-l>";
            action = "<C-w>l";
            options = { desc = "Go to Right Winddow"; remap = true; };
          }
          # Move lines
          {
            mode = "n";
            key = "<A-j>";
            action = "<cmd>m .+1<cr>==";
            options.desc = "Move Down";
          }
          {
            mode = "n";
            key = "<A-k>";
            action = "<cmd>m .-2<cr>==";
            options.desc = "Move Up";
          }
          {
            mode = "i";
            key = "<A-j>";
            action = "<esc><cmd>m .+1<cr>==gi";
            options.desc = "Move Down";
          }
          {
            mode = "i";
            key = "<A-k>";
            action = "<esc><cmd>m .-2<cr>==gi";
            options.desc = "Move Up";
          }
          {
            mode = "v";
            key = "<A-j>";
            action = ":m '>+1<cr>gv=gv";
            options.desc = "Move Down";
          }
          {
            mode = "v";
            key = "<A-k>";
            action = ":m '<-2<cr>gv=gv";
            options.desc = "Move Up";
          }
          # Better indenting
          {
            mode = "v";
            key = "<";
            action = "<gv";
          }
          {
            mode = "v";
            key = ">";
            action = ">gv";
          }
        ];

        plugins = {
          lazy = {
            enable = true;
            plugins = [
              {
                pkg = pkgs.vimPlugins.mini-nvim;
                event = "VeryLazy";
                opts.__raw = /*lua*/ ''
                  {
                    modes = { insert = true, command = true, terminal = false },
                    -- skip autopair when next character is one of these
                    skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
                    -- skip autopair when the cursor is inside these treesitter nodes
                    skip_ts = { "string" },
                    -- skip autopair when next character is closing pair
                    -- and there are more closing pairs than opening pairs
                    skip_unbalanced = true,
                    -- better deal with markdown code blocks
                    markdown = true,
                  }
                '';
                config = /*lua*/ ''
                  function (_, opts)
                    local pairs = require("mini.pairs")
                    pairs.setup(opts)
                    local open = pairs.open
                    pairs.open = function(pair, neigh_pattern)
                      if vim.fn.getcmdline() ~= "" then
                        return open(pair, neigh_pattern)
                      end
                      local o, c = pair:sub(1, 1), pair:sub(2, 2)
                      local line = vim.api.nvim_get_current_line()
                      local cursor = vim.api.nvim_win_get_cursor(0)
                      local next = line:sub(cursor[2] + 1, cursor[2] + 1)
                      local before = line:sub(1, cursor[2])
                      if opts.markdown and o == "`" and vim.bo.filetype == "markdown" and before:match("^%s*``") then
                        return "`\n```" .. vim.api.nvim_replace_termcodes("<up>", true, true, true)
                      end
                      if opts.skip_next and next ~= "" and next:match(opts.skip_next) then
                        return o
                      end
                      if opts.skip_ts and #opts.skip_ts > 0 then
                        local ok, captures = pcall(vim.treesitter.get_captures_at_pos, 0, cursor[1] - 1, math.max(cursor[2] - 1, 0))
                        for _, capture in ipairs(ok and captures or {}) do
                          if vim.tbl_contains(opts.skip_ts, capture.capture) then
                            return o
                          end
                        end
                      end
                      if opts.skip_unbalanced and next == c and c ~= o then
                        local _, count_open = line:gsub(vim.pesc(pair:sub(1, 1)), "")
                        local _, count_close = line:gsub(vim.pesc(pair:sub(2, 2)), "")
                        if count_close > count_open then
                          return o
                        end
                      end
                      return open(pair, neigh_pattern)
                    end
                  end
                '';
              }
              {
                pkg = pkgs.vimPlugins.lualine-nvim;
                event = "VeryLazy";
                init = /*lua*/ ''
                  function()
                    vim.g.lualine_laststatus = vim.o.laststatus
                    if vim.fn.argc(-1) > 0 then
                      -- set an empty statusline till lualine loads
                      vim.o.statusline = " "
                    else
                      -- hide the statusline on the starter page
                      vim.o.laststatus = 0
                    end
                  end
                '';
                opts.__raw = /*lua*/ ''
                  {
                    options = {
                      icons_enabled = true,
                    }
                  }
                '';
              }
              {
                pkg = pkgs.unstable.vimPlugins.neogit;
                dependencies = [ pkgs.vimPlugins.plenary-nvim pkgs.vimPlugins.diffview-nvim pkgs.vimPlugins.telescope-nvim ];
                event = "VeryLazy";
                config = true;
              }
              {
                pkg = pkgs.vimPlugins.gitsigns-nvim;
                opts.__raw = /*lua*/ ''
                  {
                    on_attach = function(buffer)
                      local gs = package.loaded.gitsigns

                      local function map(mode, l ,r, desc)
                        vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc})
                      end

                      map("n", "<leader>h;", function()
                        if vim.wo.diff then
                          vim.cmd.normal({ "]c", bang = true })
                        else
                          gs.nav_hunk("next")
                        end
                      end, "Next Hunk")
                      map("n", "<leader>h,", function()
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
                pkg =
                  (pkgs.vimUtils.buildVimPlugin {
                    name = "yazi.nvim";
                    src = inputs.vim-yazi;
                  });
                event = "VeryLazy";
                keys.__raw = /*lua*/ ''
                  {
                    { "<leader>.", function() require("yazi").yazi() end, desc = "Open file manager" },
                    { "<bs>", desc = "Decrement Selection", mode = "x" },
                  }
                '';
                opts.__raw = /*lua*/ ''
                  {
                    open_for_directories = true,
                  }
                '';
              }
              {
                pkg = pkgs.unstable.vimPlugins.fidget-nvim;
                opts.__raw = /*lua*/ ''
                  {
                    logger = { level = vim.log.levels.WARN },
                    notification = { filter = vim.log.levels.INFO },
                  }
                '';
              }
              {
                pkg = pkgs.unstable.vimPlugins.indent-blankline-nvim;
                event = "VeryLazy";
                main = "ibl";
                opts = {
                  scope.enabled = false;
                };
              }
              {
                pkg = pkgs.unstable.vimPlugins.vim-sleuth;
              }
              {
                pkg = pkgs.unstable.vimPlugins.comment-nvim;
              }
              {
                pkg = pkgs.vimPlugins.leap-nvim;
                config = /*lua*/ ''
                  function (_, opts)
                    local leap = require("leap")
                    for k, v in pairs(opts) do
                      leap.opts[k] = v
                    end
                    leap.add_default_mappings(true)
                  end
                '';
              }
              {
                pkg = pkgs.vimPlugins.telescope-nvim;
                dependencies = [
                  pkgs.vimPlugins.plenary-nvim
                  pkgs.vimPlugins.nvim-web-devicons
                  pkgs.vimPlugins.telescope-ui-select-nvim
                  pkgs.vimPlugins.telescope-fzf-native-nvim
                ];
                opts.__raw = /*lua*/ ''
                  {
                    defaults = {
                      layout_config = {
                        vertical = { width = 0.9 }
                      },
                    },
                  }
                '';
              }
              {
                pkg = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
                lazy.__raw = "vim.fn.argc(-1) == 0";
                init = /*lua*/ ''
                  function(plugin)
                    -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
                    -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
                    -- no longer trigger the **nvim-treesitter** module to be loaded in time.
                    -- Luckily, the only things that those plugins need are the custom queries, which we make available
                    -- during startup.
                    require("lazy.core.loader").add_to_rtp(plugin)
                    require("nvim-treesitter.query_predicates")
                  end
                '';
                cmd = [ "TSUpdateSync" "TSUpdate" "TSInstall" ];
                keys.__raw = /*lua*/ ''
                  {
                    { "<c-space>", desc = "Increment Selection" },
                    { "<bs>", desc = "Decrement Selection", mode = "x" },
                  }
                '';
                opts.__raw = /*lua*/ ''
                  {
                    highlight = { enable = true },
                    indent = { enable = true },
                    ensure_installed = "all",
                    parser_install_dir = vim.fs.joinpath(vim.fn.stdpath('data'), 'site'),
                    incremental_selection = {
                      enable = true,
                      keymaps = {
                        init_selection = "<C-space>",
                        node_incremental = "<C-space>",
                        scope_incremental = false,
                        node_decremental = "<bs>",
                      },
                    },
                    ignore_install = { "org" },
                  }
                '';
                config = /*lua*/ ''
                  function (_, opts)
                    require("nvim-treesitter.configs").setup(opts)
                    vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fn.stdpath('data'), 'site'))
                  end
                '';
              }
              {
                pkg = pkgs.unstable.vimPlugins.which-key-nvim;
                event = "VimEnter";
                config = /*lua*/ ''
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
                    }
                  end
                '';
              }
              {
                pkg = pkgs.vimPlugins.nvim-lspconfig;
                config = /*lua*/ ''
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
                    setup("sqls", {})
                    setup("nixd", {})
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
                pkg = pkgs.unstable.vimPlugins.nvim-metals;
                dependencies = [ pkgs.vimPlugins.plenary-nvim ];
                ft = [ "scala" "sbt" ];
                opts.__raw = /*lua*/ ''
                  function()
                    local metals_config = require("metals").bare_config()
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
                    metals_config.init_options.statusBarProvider = "off"
                    metals_config.settings = {
                        showImplicitArguments = true,
                    }
                    return metals_config
                  end
                '';
                config = /*lua*/ ''
                  function (self, metals_config)
                    local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
                    vim.api.nvim_create_autocmd("FileType", {
                      pattern = self.ft,
                      callback = function()
                        require("metals").initialize_or_attach(metals_config)
                      end,
                      group = nvim_metals_group,
                    })
                  end
                '';
              }
              {
                pkg = pkgs.unstable.vimPlugins.nvim-cmp;
                event = "InsertEnter";
                dependencies = [
                  pkgs.unstable.vimPlugins.cmp-nvim-lsp
                  pkgs.unstable.vimPlugins.cmp-path
                  pkgs.unstable.vimPlugins.cmp-buffer
                ];
                opts.__raw = /*lua*/ ''
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
              #   pkg = pkgs.unstable.vimPlugins.orgmode;
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
              #   dependencies = [ pkgs.unstable.vimPlugins.orgmode ];
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

        # LSP
        yaml-language-server
        typos-lsp
        nodePackages.typescript-language-server
        terraform-ls
        sqls
        nixd
        marksman
        lua-language-server
        docker-compose-language-service
        bash-language-server
      ];
    };
  };
}
