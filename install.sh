#!/bin/sh
#
# install.sh - set up a new Mac or Linux machine with these dotfiles.
#
# Run it with this one command:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
#
# What it does:
#   1. Checks that it can run: as your own user (not root), with curl.
#   2. Gets chezmoi, the tool that manages these dotfiles, into ~/.local/bin if
#      it isn't installed. It stays there; `chezmoi upgrade` updates it.
#   3. Checks that this system is supported (macOS on Apple silicon, or Linux on
#      x86_64 or ARM64) and that chezmoi's folder holds no other dotfiles.
#   4. Runs `chezmoi init --apply`. That downloads this repository, asks the
#      setup questions and writes the dotfiles. Then it runs the scripts in
#      home/.chezmoiscripts, which install Homebrew, the Brewfile's packages
#      and gh-dash, and make zsh your login shell. If one of them fails, for
#      example because Homebrew can't be installed, the dotfiles are still in
#      place.
#   5. If Homebrew is installed now, runs `chezmoi init` and `chezmoi apply`
#      once more: the dotfiles and chezmoi's own settings only set up Homebrew
#      and its programs once they exist.
#   6. Lists what you still have to do by hand, such as asking an administrator
#      to change your login shell. Where you answer no to "Use sudo on this
#      machine", setup never runs sudo, so it never asks for a sudo password.
#
# It is safe to run again: an existing ~/.local/share/chezmoi is reused. Any
# arguments you give this script are passed on to `chezmoi init`. If a step
# failed, the script ends with an error (exit status 1) after the list.

# Stop at the first command that fails (-e), and treat an unset variable as an
# error instead of quietly using an empty value (-u).
set -eu

# The GitHub user whose "dotfiles" repository this sets up. If you fork these
# dotfiles, change this (and the command above) to your GitHub username.
repo=seven7thirty3five5

# error MESSAGE: print MESSAGE as an error (>&2) and stop with exit status 1.
error() {
  echo "error: $1" >&2
  exit 1
}

# --- 1. Check that it can run -----------------------------------------------

# The dotfiles belong in your own home folder, and Homebrew refuses to run as
# root (the administrator account). `id -u` prints your user ID; root's is 0.
if [ "$(id -u)" -eq 0 ]; then
  error "run install.sh as your own user, not as root or with sudo."
fi

# curl downloads chezmoi and Homebrew. `command -v` prints where a program is
# installed, or fails if it isn't; ">/dev/null 2>&1" throws away its output,
# and ! turns failure into success.
if ! command -v curl >/dev/null 2>&1; then
  error "install.sh needs curl; install it first."
fi

# --- 2. Get chezmoi ---------------------------------------------------------

# Use chezmoi if it's installed. ~/.local/bin isn't on PATH yet on a new
# machine (the dotfiles put it there), so look in it as well (-x: a program we
# can run).
bin_dir=$HOME/.local/bin
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi=$(command -v chezmoi)
elif [ -x "$bin_dir/chezmoi" ]; then
  chezmoi=$bin_dir/chezmoi
else
  # Download chezmoi's official installer and let it put chezmoi in
  # ~/.local/bin (-b), where it stays. The installer is saved in a variable
  # first, so that if the download fails, this script stops right here
  # instead of running an empty installer.
  chezmoi_installer=$(curl -fsLS https://get.chezmoi.io)
  mkdir -p "$bin_dir"
  sh -c "$chezmoi_installer" -- -b "$bin_dir"
  chezmoi=$bin_dir/chezmoi
fi

# --- 3. Check this system ---------------------------------------------------

# Ask chezmoi which system this is: darwin (macOS) or linux, then amd64 (Intel
# or AMD) or arm64 (Apple silicon, ARM servers). `case` compares the answer
# with each pattern in turn, and ;; ends the commands for a pattern.
platform=$("$chezmoi" execute-template '{{ .chezmoi.os }}/{{ .chezmoi.arch }}')
case $platform in
  darwin/arm64 | linux/amd64 | linux/arm64) ;;
  darwin/amd64)
    error "Intel Macs are not supported; these dotfiles need Homebrew in /opt/homebrew."
    ;;
  *)
    error "$platform is not supported; these dotfiles support macOS on Apple silicon and Linux on x86_64 or ARM64."
    ;;
esac

# An existing chezmoi folder must hold this repository, or `chezmoi init` would
# quietly use whatever is there. .chezmoi.workingTree is that folder
# (~/.local/share/chezmoi by default), and its .git/config file records where
# it was downloaded from. (-d: the folder exists. grep -E searches for a
# pattern, in which [:/] matches the : or / before the username; -q only
# reports whether it was found, and -s stays quiet if the file is missing.)
source_dir=$("$chezmoi" execute-template '{{ .chezmoi.workingTree }}')
if [ -d "$source_dir" ] \
  && ! grep -Eqs "github\.com[:/]$repo/dotfiles" "$source_dir/.git/config"; then
  error "$source_dir holds other dotfiles; move it away, then run install.sh again."
fi

# --- 4. Download and apply the dotfiles -------------------------------------

# --use-builtin-git=true makes chezmoi clone with its own Git. On a new Mac,
# /usr/bin/git only offers to install Apple's Command Line Tools, which
# Homebrew installs later anyway. --keep-going makes chezmoi carry on when a
# setup script fails: it still writes the dotfiles and runs the other scripts,
# then reports the failure. `|| failed=1` remembers that failure instead of
# stopping this script. "$@" stands for this script's arguments.
failed=0
"$chezmoi" init --apply --keep-going --use-builtin-git=true "$@" "$repo" || failed=1

# Without the repository there's nothing more to do, for example when there
# was no network to download it.
if [ ! -d "$source_dir" ]; then
  error "chezmoi couldn't download the dotfiles; see the error above."
fi

# --- 5. Pick up Homebrew ----------------------------------------------------

# Ask chezmoi where Homebrew is: the brew-prefix template prints its folder,
# or nothing if Homebrew isn't installed. (-n: the text isn't empty.)
prefix=$("$chezmoi" execute-template '{{ includeTemplate "brew-prefix" . }}')
if [ -n "$prefix" ]; then
  # Add Homebrew to this script's PATH: `brew shellenv sh` prints the
  # `export ...` commands that do that, and `eval` runs them. The output is
  # saved in a variable first, so that if brew fails, the script stops there.
  brew_env=$("$prefix/bin/brew" shellenv sh)
  eval "$brew_env"

  # The dotfiles only set up Homebrew and its programs once they exist, and
  # step 4 wrote them before its scripts installed Homebrew, so write them
  # again. `chezmoi init` first records delta and nvim in chezmoi's own
  # settings; `chezmoi apply` also retries any setup script that failed. This
  # second round decides whether setup failed.
  failed=0
  "$chezmoi" init "$@" || failed=1
  "$chezmoi" apply --keep-going || failed=1
fi

# --- 6. List what's left to do by hand --------------------------------------

# Setup doesn't stop for steps that need an administrator. Instead, this checks
# what's still missing and collects what you need to do in $todo, one step per
# line, to print at the end.
todo=

# Ask chezmoi how you answered "Use sudo on this machine" (true or false) and
# which system this is (darwin on macOS); the steps below depend on both.
use_sudo=$("$chezmoi" execute-template '{{ .useSudo }}')
os=$("$chezmoi" execute-template '{{ .chezmoi.os }}')

# Homebrew installs everything else, so without it setup has failed. On a Mac,
# only an administrator can install it.
if [ -z "$prefix" ]; then
  failed=1
  if [ "$os" = darwin ] && [ "$use_sudo" != true ]; then
    todo="$todo
  - Ask IT (an administrator) to install Homebrew in /opt/homebrew, then run
    install.sh again."
  else
    todo="$todo
  - Install Homebrew: fix the error shown above, then run install.sh again."
  fi
fi

# Is zsh your login shell yet? dscl (macOS) or getent (Linux) looks it up, as
# in the login shell script. Where setup may use sudo, it switches to the
# system's zsh: /bin/zsh on macOS, /usr/bin/zsh on Linux.
user=$(id -un)
if [ "$os" = darwin ]; then
  login_shell=$(dscl . -read "/Users/$user" UserShell | awk '{print $2}')
  zsh=/bin/zsh
else
  login_shell=$(getent passwd "$user" | cut -d: -f7)
  zsh=/usr/bin/zsh
fi

if [ "$use_sudo" = true ]; then
  if [ "$login_shell" != "$zsh" ]; then
    # Setup tried with sudo but couldn't, for example because sudo's password
    # prompt timed out.
    todo="$todo
  - Make $zsh your login shell: run  sudo chsh -s $zsh $user
    (if IT manages your account, ask them to change it instead)."
  fi
else
  # Without sudo, any zsh that an administrator sets up will do. (*/zsh
  # matches any path that ends in /zsh.) If zsh is installed already, name it.
  case $login_shell in
    */zsh) ;;
    *)
      if installed_zsh=$(command -v zsh); then
        todo="$todo
  - Ask IT (an administrator) to make $installed_zsh your login shell.
    Until then, start zsh by typing zsh"
      else
        todo="$todo
  - Ask IT (an administrator) to install zsh and make it your login shell."
      fi
      ;;
  esac
fi

# Programs that need sudo to install, so setup installs them only on Linux with
# sudo: a C compiler (cc) builds Neovim's syntax highlighting, Homebrew needs
# file and git, and Neovim's Mason uses unzip.
missing=
for tool in cc file git unzip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing="$missing $tool"
  fi
done

if [ -n "$missing" ]; then
  if [ "$use_sudo" = true ]; then
    todo="$todo
  - Install with your system's package manager:$missing"
  else
    todo="$todo
  - Ask IT (an administrator) to install:$missing"
  fi
fi

# -n: the text isn't empty, so there is something left to do.
if [ -n "$todo" ]; then
  echo "Still to do:$todo"
fi

# If a step failed, say so and end with exit status 1 (-ne: not equal).
if [ "$failed" -ne 0 ]; then
  echo "Setup finished with errors (see above). The dotfiles are installed;" \
    "fix the errors, then run install.sh again." >&2
  exit 1
fi

echo "Done. Open a new terminal to start using the new setup."
