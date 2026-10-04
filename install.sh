#!/bin/sh
# Set up a new macOS or Linux machine with these dotfiles in one command:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
#
# `chezmoi init --apply` does the work: the scripts in home/.chezmoiscripts install
# Homebrew (choosing its prefix by sudo access), the Brewfile, gh-dash and LazyVim's
# plugins, and make zsh the login shell. `chezmoi init` then runs once more because
# chezmoi's own config looks for delta and nvim, which did not exist the first time,
# and a chezmoi script cannot run chezmoi itself.
#
# Arguments are passed to `chezmoi init` (CI uses --promptDefaults). Re-running is safe:
# an existing ~/.local/share/chezmoi is reused, not cloned again.
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
trap 'exit 1' HUP INT TERM

if command -v chezmoi >/dev/null 2>&1; then
  chezmoi=$(command -v chezmoi)
else
  # A temporary copy only; the Brewfile installs chezmoi with Homebrew for everyday use.
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$tmpdir"
  chezmoi=$tmpdir/chezmoi
fi

"$chezmoi" init --apply "$@" seven7thirty3five5
"$chezmoi" init "$@"

echo "Done. Open a new terminal to start using the new setup."
