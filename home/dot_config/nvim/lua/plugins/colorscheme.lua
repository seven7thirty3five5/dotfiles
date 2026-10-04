-- Catppuccin ships with LazyVim; select it and pin the Mocha flavour.
-- A file in lua/plugins/ returns a list of plugin "specs": a plugin's name and
-- how to set it up. LazyVim merges each one into its own spec for the same
-- plugin, so these only change what's listed: catppuccin's flavour, and the
-- colorscheme LazyVim uses.
return {
  { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "mocha" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
