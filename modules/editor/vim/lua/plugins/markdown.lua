return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      heading = {
        icons = { "H1 ", "H2 ", "H3 ", "H4 ", "H5 ", "H6 " },
        position = "inline",
        backgrounds = {},
      },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      zen = {
        win = {
          width = function(win)
            local ft = vim.bo[win.buf].filetype
            return (ft == "markdown" or ft == "markdown.mdx") and 100 or 120
          end,
        },
        on_open = function(win)
          -- Recompute the reading width when switching buffers inside Zen.
          win:on({ "BufWinEnter", "FileType" }, function(self)
            vim.schedule(function()
              self:update()
            end)
          end)
        end,
      },
    },
  },
}
