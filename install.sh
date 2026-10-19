#!/bin/sh
#
# install.sh: set up these dotfiles on a new Mac or Linux machine. The README
# has the command that downloads and runs it; running it again is safe.
#
# It installs chezmoi in ~/.local/bin. Then `chezmoi init --apply` clones this
# repository, asks the setup questions, writes the dotfiles and runs the setup
# scripts in home/.chezmoiscripts, which install Homebrew and its packages,
# mise's runtimes and the agent skills. Arguments go to `chezmoi init`.

set -eu

# Homebrew refuses to run as root, and the dotfiles belong in your own home.
if [ "$(id -u)" -eq 0 ]; then
  echo "error: run install.sh as your own user, not as root or with sudo." >&2
  exit 1
fi

bin_dir=$HOME/.local/bin
chezmoi=$bin_dir/chezmoi
if [ ! -x "$chezmoi" ]; then
  # Saved first, so a failed download stops here rather than running nothing.
  installer=$(curl -fsLS https://get.chezmoi.io)
  mkdir -p "$bin_dir"
  sh -c "$installer" -- -b "$bin_dir"
fi

# --use-builtin-git: on a new Mac, /usr/bin/git only offers to install Apple's
# Command Line Tools, which Homebrew installs anyway. --keep-going: a failed
# setup script doesn't stop the others, and the dotfiles are written first.
failed=0
"$chezmoi" init --apply --keep-going --use-builtin-git=true "$@" seven7thirty3five5 || failed=1

# Without the repository there's nothing more to do, for example offline.
[ -d "$("$chezmoi" execute-template '{{ .chezmoi.workingTree }}')" ] || exit 1

# chezmoi's settings and git's use delta (and chezmoi's, fish) once Homebrew
# has installed them, which happened after they were written. Write them again.
prefix=$("$chezmoi" execute-template '{{ includeTemplate "brew-prefix" . | trim }}')
PATH=$prefix/bin:$PATH "$chezmoi" init "$@" || failed=1
"$chezmoi" apply --exclude=scripts || failed=1

# What's left for you, or an administrator, to do.
todo=
if [ ! -x "$prefix/bin/brew" ]; then
  todo="$todo
  - Install Homebrew: fix the error shown above, then run install.sh again."
fi

# Your login shell finds herdr in ~/.local/bin, and the dotfiles never edit its
# startup files.
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) todo="$todo
  - Put ~/.local/bin on your login shell's PATH, as the README describes. On
    Debian and Ubuntu, logging in again does it now that the folder exists." ;;
esac

# Homebrew needs these. The system-packages script installs them on Linux with
# sudo; without sudo, an administrator has to.
missing=
for tool in cc file git; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  todo="$todo
  - Install with the system's package manager, or ask an administrator to:$missing"
fi

if [ -n "$todo" ]; then
  echo "Still to do:$todo"
fi

if [ "$failed" -ne 0 ]; then
  echo "Setup finished with errors (see above); fix them, then run install.sh again." >&2
  exit 1
fi
echo "Done. Open a new terminal to start using the new setup."
