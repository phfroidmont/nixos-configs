-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local ts_ledger = vim.api.nvim_create_augroup("treesitter_ledger", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = ts_ledger,
  pattern = { "ledger" },
  callback = function(args)
    pcall(vim.treesitter.start, args.buf, "ledger")
  end,
})
