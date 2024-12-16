return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
  {
    'nvim-telescope/telescope.nvim',
    opts = {
      defaults = { path_display = { "truncate" } },
    },
  },
  {
    'folke/snacks.nvim',
    keys = {
      { "<leader>bk", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
    },
  },
}
