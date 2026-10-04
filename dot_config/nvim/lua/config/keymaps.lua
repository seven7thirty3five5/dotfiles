-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- 2. Keep Cursor Centered While Scrolling and Searching
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
-- n always searches forward and N backward, even after ?, as LazyVim's own n/N do
-- (vim-galore's "saner behavior of n and N"); zz centers the match, zv opens its fold.
map("n", "n", "'Nn'[v:searchforward].'zzzv'", { expr = true, desc = "Next search result and center" })
map("n", "N", "'nN'[v:searchforward].'zzzv'", { expr = true, desc = "Prev search result and center" })
