#!/bin/sh
#
# install.sh - set up a new Mac or Linux machine with these dotfiles.
#
# Run it with this one command:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
#
# What it does:
#   1. Gets chezmoi, the tool that manages these dotfiles, if it isn't installed.
#   2. Runs `chezmoi init --apply`. That downloads this repository, writes the
#      dotfiles, and runs the scripts in home/.chezmoiscripts, which install
#      Homebrew, the Brewfile's packages, gh-dash and LazyVim's plugins, and make
#      zsh your login shell.
#   3. Runs `chezmoi init` once more. chezmoi's own settings use delta (for diffs)
#      and nvim (for merges) only if they exist, and they didn't before step 2.
#
# It is safe to run again: an existing ~/.local/share/chezmoi is reused.
# Any arguments you give this script are passed on to `chezmoi init`.

# Stop at the first command that fails (-e), and treat an unset variable as an
# error instead of quietly using an empty value (-u).
set -eu

# --- 1. Get chezmoi ---------------------------------------------------------

# Make a temporary folder for a throwaway copy of chezmoi. `trap ... EXIT` runs
# the quoted commands when this script ends, which deletes the folder again;
# the second trap makes Ctrl-C (and similar signals) end the script cleanly.
tmpdir=$(mktemp -d)
trap 'rm -f "$tmpdir/chezmoi"; rmdir "$tmpdir"' EXIT
trap 'exit 1' HUP INT TERM

# `command -v chezmoi` prints where chezmoi is installed, or fails if it isn't.
# ">/dev/null 2>&1" throws away its output; only success or failure matters.
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi=$(command -v chezmoi)
else
  # Download chezmoi's official installer and let it put chezmoi in the
  # temporary folder (-b). The Brewfile installs a permanent copy later.
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$tmpdir"
  chezmoi=$tmpdir/chezmoi
fi

# --- 2. Download and apply the dotfiles --------------------------------------

# --use-builtin-git=true makes chezmoi clone with its own Git. On a new Mac,
# /usr/bin/git only offers to install Apple's Command Line Tools, which
# Homebrew installs later anyway. "$@" stands for this script's arguments.
"$chezmoi" init --apply --use-builtin-git=true "$@" seven7thirty3five5

# --- 3. Refresh chezmoi's own settings ---------------------------------------

# Step 2 installed Homebrew in a separate process, so this script doesn't know
# about it yet. First ask chezmoi where Homebrew is: the brew-prefix template
# prints its folder. (-z: the text is empty; ! -x: not a program we can run;
# >&2 prints the message as an error.)
prefix=$("$chezmoi" execute-template '{{ includeTemplate "brew-prefix" . }}')
if [ -z "$prefix" ] || [ ! -x "$prefix/bin/brew" ]; then
  echo "error: Homebrew not found after applying the dotfiles." >&2
  exit 1
fi

# Then add Homebrew to this script's PATH: `brew shellenv sh` prints the
# `export ...` commands that do that, and `eval` runs them. The output is saved
# in a variable first, so that if brew fails, the script stops right there.
brew_env=$("$prefix/bin/brew" shellenv sh)
eval "$brew_env"

# delta and nvim are on PATH now, so this records them in chezmoi's settings.
"$chezmoi" init "$@"

echo "Done. Open a new terminal to start using the new setup."
