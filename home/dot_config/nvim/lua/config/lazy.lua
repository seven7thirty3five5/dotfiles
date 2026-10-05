-- From LazyVim's starter template: install and start lazy.nvim, the plugin
-- manager, which then loads LazyVim and the plugins.

-- If lazy.nvim isn't installed yet, download it with git into Neovim's data
-- folder (~/.local/share/nvim/lazy/lazy.nvim). If that fails, show the error
-- and quit.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Add lazy.nvim to the runtimepath, the list of folders Neovim loads code from.
vim.opt.rtp:prepend(lazypath)

-- Start lazy.nvim with LazyVim's plugins and your own (the files in
-- lua/plugins/); the first time Neovim starts, lazy.nvim installs them all.
-- Two JSON files next to this config can't hold comments: lazyvim.json, which
-- lists the LazyVim "extras" (optional plugin bundles) turned on with
-- :LazyExtras, and lazy-lock.json, in which lazy.nvim records the exact version
-- of each plugin on this machine. The dotfiles track lazyvim.json, but each
-- machine keeps its own lazy-lock.json (see .chezmoiignore).
require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- import/override with your plugins
    { import = "plugins" },
  },

  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,

    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },

  -- The colors to use while plugins are being installed on the first start.
  install = { colorscheme = { "catppuccin", "habamax" } },

  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates

  performance = {
    rtp = {
      -- disable some rtp plugins
      -- (plugins that come with Neovim: for reading .gz, .tar and .zip files,
      -- :TOhtml and :Tutor)
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
