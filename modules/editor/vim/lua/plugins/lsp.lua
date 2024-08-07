return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        metals = {
          settings = {
            showImplicitArguments = false,
          },
        },
      },
    },
  },
}
