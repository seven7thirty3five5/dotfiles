# Runs after 10-homebrew.fish, so these end up in front of Homebrew. --global
# --path changes this shell's PATH rather than the saved fish_user_paths, and
# fish_add_path skips folders that don't exist yet.

# ~/.local/bin (chezmoi, mise and the link to herdr) before Homebrew. mise's
# runtime paths may precede it, so a project's runtime choice takes priority.
fish_add_path --global --move --path $HOME/.local/bin

# Docker Desktop's command-line tools, at the end.
fish_add_path --global --append --path $HOME/.docker/bin

# mise's shims, so scripts and herdr's popups find the runtimes too. This is
# the line `mise activate fish --shims` prints, without running mise.
fish_add_path --global --move --path $XDG_DATA_HOME/mise/shims

# Micro when installed, else vi; set once PATH is final. Some programs read
# VISUAL instead of EDITOR.
if command -q micro
    set -gx EDITOR micro
else
    set -gx EDITOR vi
end

set -gx VISUAL $EDITOR
