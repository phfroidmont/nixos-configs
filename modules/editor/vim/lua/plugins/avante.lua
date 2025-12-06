return {
  "yetone/avante.nvim",
  opts = {
    provider = "opencode",
    {
      acp_providers = {
        ["opencode"] = {
          command = "opencode",
          args = { "acp" }
        }
      }
    },
  },
  keys = {
    { "<leader>aa", "<cmd>AvanteAsk<CR>",  mode = { "n", "v" }, desc = "Ask Avante" },
    { "<leader>ae", "<cmd>AvanteEdit<CR>", mode = { "n", "v" }, desc = "Edit Avante" },
  },
}
