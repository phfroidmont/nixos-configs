-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Windows
map("n", "<leader>ww", "<C-w>p", { desc = "Other Window", remap = true })
map("n", "<leader>wd", "<C-w>c", { desc = "Delete Window", remap = true })
map("n", "<leader>ws", "<C-w>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>wv", "<C-w>v", { desc = "Split Window Right", remap = true })
map("n", "<leader>wj", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<leader>wk", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<leader>wl", "<C-w>l", { desc = "Go to Right Window", remap = true })
map("n", "<leader>wh", "<C-w>h", { desc = "Go to Left Window", remap = true })

-- File
map("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save File" })
