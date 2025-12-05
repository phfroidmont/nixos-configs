return {
  "yetone/avante.nvim",
  opts = {
    -- add any opts here
    -- this file can contain specific instructions for your project
    instructions_file = "avante.md",
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
}
