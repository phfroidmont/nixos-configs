return {
  "zk-org/zk-nvim",
  keys = {
    {
      "<leader>zn",
      "<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>",
      desc = "Create a new note after asking for its title"
    },
    {
      "<leader>zo",
      "<Cmd>ZkNotes { sort = { 'modified' } }<CR>",
      desc = "Open Notes"
    },
    {
      "<leader>zt",
      "<Cmd>ZkTags<CR>",
      desc = "Open notes associated with the selected tags"
    },
    {
      "<leader>zf",
      "<Cmd>ZkNotes { sort = { 'modified' }, match = { vim.fn.input('Search: ') } }<CR>",
      desc = "Search for the notes matching a given query"
    },
    {
      "<leader>zf",
      ":'<,'>ZkMatch<CR>",
      mode = { "v" },
      desc = "Search for the notes matching the current visual selection"
    },
  },
  config = function()
    require("zk").setup({
      picker = "fzf_lua",

      lsp = {
        -- `config` is passed to `vim.lsp.start(config)`
        config = {
          name = "zk",
          cmd = { "zk", "lsp" },
          filetypes = { "markdown" },
          -- on_attach = ...
          -- etc, see `:h vim.lsp.start()`
        },

        -- automatically attach buffers in a zk notebook that match the given filetypes
        auto_attach = {
          enabled = true,
        },
      },
    })
  end,
}
