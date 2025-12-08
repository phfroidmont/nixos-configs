return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    sections = {
      lualine_z = {
        {
          require("opencode").statusline,
        },
      }
    }
  },
}

