return {
  "NickvanDyke/opencode.nvim",
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      provider = {
        enabled = "kitty",
        kitty = {
          location = "tab"
        }
      },
      events = {
        permissions = {
          enabled = false
        }
      }
    }
    vim.o.autoread = true

    vim.keymap.set({ "n", "x" }, "<leader>aa", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask opencode" })

    vim.keymap.set({ "n", "x" }, "<leader>ao", function()
      require("opencode").select()
    end, { desc = "Execute opencode action…" })

    vim.keymap.set({ "n", "x" }, "<leader>as", function()
      require("opencode").prompt("@this")
    end, { desc = "Add to opencode" })

    vim.keymap.set({ "n", "t" }, "<leader>a.", function()
      require("opencode").toggle()
    end, { desc = "Toggle opencode" })
  end,
}
