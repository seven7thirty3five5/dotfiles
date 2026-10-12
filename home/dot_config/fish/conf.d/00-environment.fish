# ~/.config/fish/conf.d/00-environment.fish: the environment every fish gets,
# including the fish that herdr starts for its popups (`fish -c lazygit`) and
# the ones that run scripts. This is the only place your environment is
# defined; the login shells (~/.zprofile on macOS, ~/.bashrc on Linux) only add
# Homebrew so that you can start herdr.
#
# fish runs every file in conf.d, in name order, before config.fish, and it does
# that for every fish: interactive or not, login or not. The numbers at the
# start of the names set the order: 00 (this file) sets the environment, 10 adds
# Homebrew, and 20 puts your own programs first and picks the editor.
#
# This file must never print anything: what a shell prints while starting can
# break programs that talk to it, such as scp, rsync or git over SSH.
#
# How to read fish:
#   set -gx NAME VALUE  sets a variable. -g makes it global (the whole shell,
#                       not just this file) and -x exports it to the programs
#                       fish starts.
#   set -q NAME         succeeds if NAME is set ("query").
#   A; or B             runs B only if A failed (`A; and B`: only if it worked).
#   $NAME               the variable's value. fish never splits a value on
#                       spaces, so variables need no quotes around them.

# The XDG base directories: the standard folders where programs keep their
# settings (config), data, state (such as history and logs) and cache. Set them
# first, because many tools fall back to ~/Library on macOS when they're
# missing. Each line keeps a value this machine already set. (fish found its own
# folders before reading this file; they are these same defaults.)
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME $HOME/.config
set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME $HOME/.local/share
set -q XDG_STATE_HOME; or set -gx XDG_STATE_HOME $HOME/.local/state
set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME $HOME/.cache

# Where XDG programs look for system-wide settings and data, unless already set.
# fish treats variables whose names end in DIRS like PATH: a list it exports
# joined with colons.
set -q XDG_CONFIG_DIRS; or set -gx --path XDG_CONFIG_DIRS /etc/xdg
set -q XDG_DATA_DIRS; or set -gx --path XDG_DATA_DIRS /usr/local/share /usr/share

# XDG_RUNTIME_DIR belongs to the OS/session; do not invent a persistent path.

# Tell some tools where their files are, because their defaults may bypass XDG
# on macOS: bat's and eza's config folders (eza's holds its theme), ripgrep's
# config file (rg reads none unless this is set), Starship's config file, and
# the folder for zoxide's list of folders.
set -gx BAT_CONFIG_DIR $XDG_CONFIG_HOME/bat
set -gx EZA_CONFIG_DIR $XDG_CONFIG_HOME/eza
set -gx RIPGREP_CONFIG_PATH $XDG_CONFIG_HOME/ripgrep/config
set -gx STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/config.toml
set -gx _ZO_DATA_DIR $XDG_DATA_HOME/zoxide

# Programs that show long output one screen at a time use less; -R lets less
# show colors instead of raw color codes.
set -gx PAGER less
set -gx LESS -R

# Catppuccin Mocha for fzf (from catppuccin/fzf). fzf adds FZF_DEFAULT_OPTS to
# its options every time it runs. Each option is one item of a list; fish
# exports a list like this joined with spaces. A backslash at the end of a line
# continues the command on the next line.
set -gx FZF_DEFAULT_OPTS \
    --color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
    --color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
    --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
    --color=selected-bg:#45475A \
    --color=border:#6C7086,label:#CDD6F4
