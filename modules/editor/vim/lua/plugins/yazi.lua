return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>.",
        function()
          require("yazi").yazi()
        end,
        desc = "Open the file manager",
      },
    },
    opts = {
      open_for_directories = true,
    },
  }
}
