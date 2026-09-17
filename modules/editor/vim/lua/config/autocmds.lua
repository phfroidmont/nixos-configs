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

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("markdown_reading", { clear = true }),
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    -- Keep reading quiet; <leader>us enables bilingual proofreading.
    vim.opt_local.spell = false
    vim.opt_local.spelllang = { "fr", "en" }
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    local undo = "setlocal spell< spelllang< wrap< linebreak< breakindent<"
    vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
  end,
})
