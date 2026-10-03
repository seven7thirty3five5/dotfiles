# .zshenv and env.zsh should NEVER output anything: they run in scripts and
# SSH commands too, where startup output can corrupt data or transfer protocols.
# Keep this file idempotent so macOS .zprofile can source it after path_helper.
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
# XDG_RUNTIME_DIR belongs to the OS/session; do not invent a persistent path.

# Unique entries make repeated sourcing safe; restore the same PATH priorities.
typeset -U path
path=("$HOME/.local/bin" $path)
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")
export PATH

# Explicit overrides for tools whose defaults may bypass XDG on macOS.
export BAT_CONFIG_DIR="$XDG_CONFIG_HOME/bat"
export EZA_CONFIG_DIR="$XDG_CONFIG_HOME/eza"
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/config.toml"
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"

export PAGER="less"
export LESS="-R"
export EDITOR="nvim"
export VISUAL="nvim"
