return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        nix = {
          "statix",
        },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = {
          settings = {
            nixd = {
              formatting = {
                command = { "nixfmt" }
              }
            }
          },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    lazy = false,
    opts = {
      default_format_opts = {
        lsp_format = "first"
      },
      formatters_by_ft = {
        nix = { "nixfmt" },
      },
    },
  },
}
