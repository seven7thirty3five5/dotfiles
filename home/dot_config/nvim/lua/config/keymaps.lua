-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- map(mode, keys, action, options): mode "n" is Normal mode. desc is the
-- description that which-key (LazyVim's popup of available keys) shows.
local map = vim.keymap.set

-- Keep the cursor centered while scrolling half a page with Ctrl-D and Ctrl-U:
-- zz scrolls the view so the cursor line is in the middle of the window.
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
-- n always searches forward and N backward, even after ?, as LazyVim's own n/N do
-- (vim-galore's "saner behavior of n and N"); zz centers the match, zv opens its fold.
-- expr = true: the action is an expression that works out which keys to press.
-- v:searchforward is 1 after a search forward (/) and 0 after one backward (?),
-- so 'Nn'[v:searchforward] picks whichever of n and N goes forward ('nN': backward).
map("n", "n", "'Nn'[v:searchforward].'zzzv'", { expr = true, desc = "Next search result and center" })
map("n", "N", "'nN'[v:searchforward].'zzzv'", { expr = true, desc = "Prev search result and center" })

-- Keep the cursor and view steady when joining lines (J, 3J, etc.).
-- It saves the cursor and scroll position, runs the built-in J (normal! ignores
-- key mappings, so this one doesn't call itself; count1 is the number typed
-- before J, or 1), then puts the cursor and view back.
map("n", "J", function()
  local view = vim.fn.winsaveview()
  vim.cmd.normal({ args = { tostring(vim.v.count1) .. "J" }, bang = true })
  vim.fn.winrestview(view)
end, { desc = "Join lines without moving cursor" })
