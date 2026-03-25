return {
  "NickvanDyke/opencode.nvim",
  config = function()
    local function open_opencode_in_kitty_tab()
      vim.fn.jobstart({
        "kitty",
        "@",
        "launch",
        "--type=tab",
        "--cwd",
        vim.fn.getcwd(),
        "sh",
        "-lc",
        "opencode --port",
      }, { detach = true })
    end

    ---@type opencode.Opts
    vim.g.opencode_opts = {
      server = {
        start = open_opencode_in_kitty_tab,
        toggle = open_opencode_in_kitty_tab,
        stop = function() end,
      },
      events = {
        permissions = {
          enabled = false
        }
      }
    }
    vim.o.autoread = true

    vim.keymap.set({ "n", "x" }, "<leader>oa", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask opencode" })

    vim.keymap.set({ "n", "x" }, "<leader>oo", function()
      require("opencode").select()
    end, { desc = "Execute opencode action…" })

    vim.keymap.set({ "n", "x" }, "<leader>os", function()
      require("opencode").prompt("@this")
    end, { desc = "Add to opencode" })

    vim.keymap.set({ "n", "t" }, "<leader>o.", function()
      require("opencode").toggle()
    end, { desc = "Toggle opencode" })
  end,
}
