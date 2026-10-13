# The environment for every fish, popups and scripts included. Print nothing
# here: startup output breaks scp, rsync and git over SSH.

# XDG base directories first: without them, many tools use ~/Library on macOS.
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME $HOME/.config
set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME $HOME/.local/share
set -q XDG_STATE_HOME; or set -gx XDG_STATE_HOME $HOME/.local/state
set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME $HOME/.cache

# These tools bypass the XDG folders on macOS unless told; rg reads no config
# file at all without RIPGREP_CONFIG_PATH.
set -gx BAT_CONFIG_DIR $XDG_CONFIG_HOME/bat
set -gx EZA_CONFIG_DIR $XDG_CONFIG_HOME/eza
set -gx RIPGREP_CONFIG_PATH $XDG_CONFIG_HOME/ripgrep/config
set -gx STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/config.toml
set -gx _ZO_DATA_DIR $XDG_DATA_HOME/zoxide

# less for programs that page. LESS stays unset: git, gh and fish's history add
# their own less options (so short output doesn't page) only while it is.
set -gx PAGER less

# Catppuccin Mocha for fzf (catppuccin/fzf), which yazi and zoxide's cdi run.
set -gx FZF_DEFAULT_OPTS \
    --color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
    --color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
    --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
    --color=selected-bg:#45475A \
    --color=border:#6C7086,label:#CDD6F4
