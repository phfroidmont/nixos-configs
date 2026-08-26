return {
  {
    "NeogitOrg/neogit",
    dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim", "nvim-telescope/telescope.nvim" },
    event = "VeryLazy",
    keys = {
      {
        "<leader>gg",
        "<cmd>Neogit<cr>",
        desc = "Neogit",
      },
    },
    opts = {
      treesitter_diff_highlight = true,
      word_diff_highlight = true,
    },
  },
}
