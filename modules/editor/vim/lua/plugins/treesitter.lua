return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      auto_install = false,
      sync_install = false,
      ensure_installed = {},
      parser_install_dir = vim.fs.joinpath(vim.fn.stdpath('data'), 'site'),
    },
  },
}
