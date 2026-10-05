#!/bin/sh
#
# check-install.sh - check that install.sh set this machine up correctly.
#
# The Bootstrap workflow (.github/workflows/bootstrap.yml) runs this right after
# install.sh, as the same user. If a check finds a problem, the script prints
# "FAIL: ..." and stops. If every check passes, it prints "Install checks passed".

# Stop at the first command that fails (-e), and treat an unset variable as an
# error instead of quietly using an empty value (-u).
set -eu

# fail MESSAGE: print MESSAGE as an error (>&2) and stop with exit status 1.
fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Find zsh, the shell these dotfiles configure: the system's own, which the
# setup installs on Linux with sudo (an administrator installs it elsewhere).
# `command -v zsh` prints where it is, or fails if it isn't installed.
if ! zsh=$(command -v zsh); then
  fail "zsh is not installed"
fi

# Use the same PATH a new terminal gets. We start zsh as an interactive login
# shell (-l -i), the way a terminal does, and have it print its PATH. This
# matters on Linux, where Homebrew is only added to PATH in .zshrc, a file
# other shells never read. zsh's startup warnings are thrown away (2>/dev/null)
# and only the last line of output, the PATH itself, is kept (tail -n 1).
# Expand PATH in the child zsh after it has read its startup files.
# shellcheck disable=SC2016
PATH=$("$zsh" -l -i -c 'echo "$PATH"' 2>/dev/null | tail -n 1)
export PATH

# Where the dotfiles keep config and data files. ${NAME:-default} means "the
# value of $NAME, or default when NAME isn't set".
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
data_dir=${XDG_DATA_HOME:-$HOME/.local/share}

# --- 1. The Brewfile's tools are installed and on PATH ----------------------

# The loop goes through the list one word at a time. chezmoi itself comes from
# ~/.local/bin, where install.sh puts it.
tools="brew chezmoi git delta difft nvim fzf fd rg bat eza
       atuin zoxide starship lazygit gh shellcheck shfmt act actionlint"
for tool in $tools; do
  if ! command -v "$tool" >/dev/null; then
    fail "$tool is not on PATH"
  fi
done

# --- 2. Every deployed file matches the repository --------------------------

# `chezmoi verify` succeeds when every file it manages matches the repository.
# Scripts are left out: they are steps to run, not files. If anything
# differs, show the differences.
if ! chezmoi verify --exclude=scripts; then
  chezmoi diff --no-pager --exclude=scripts >&2
  fail "deployed files differ from the repository"
fi

# --- 3. Setup left the repository unchanged ---------------------------------

# Nothing that setup runs may write into the dotfiles repository (programs that
# rewrite their own settings through a symlink into it would). `chezmoi git`
# runs git in the repository; `status --porcelain` lists changed files, one per
# line, and prints nothing when there are none. (-n: the text isn't empty.)
changes=$(chezmoi git -- status --porcelain)
if [ -n "$changes" ]; then
  echo "$changes" >&2
  fail "setup changed files in the dotfiles repository"
fi

# --- 4. The templates found Homebrew where it was installed -----------------

# The brew-prefix template is how the dotfiles find Homebrew; compare its answer
# with Homebrew's own.
template_prefix=$(chezmoi execute-template '{{ includeTemplate "brew-prefix" . }}')
brew_prefix=$(brew --prefix)
if [ "$template_prefix" != "$brew_prefix" ]; then
  fail "brew-prefix found $template_prefix, but Homebrew is in $brew_prefix"
fi

# --- 5. The git config was applied ------------------------------------------

# diff.algorithm = histogram is one of the settings in home/dot_config/git.
if [ "$(git config --get diff.algorithm)" != histogram ]; then
  fail "the git config was not applied"
fi

# --- 6. chezmoi's own settings found delta ----------------------------------

# install.sh runs `chezmoi init` a second time so that chezmoi's settings
# include delta as the pager for `chezmoi diff`, in a [diff] section.
# grep -q only reports whether a line starts with "[diff]".
if ! grep -q '^\[diff\]' "$config_dir/chezmoi/chezmoi.toml"; then
  fail "chezmoi's config has no [diff] pager; the second chezmoi init did not run"
fi

# --- 7. gh's config is a symlink into the repository ------------------------

# gh rewrites its config file, so it links to the copy in the repository
# instead (-L: the file is a symbolic link).
if [ ! -L "$config_dir/gh/config.yml" ]; then
  fail "$config_dir/gh/config.yml is not a symlink into the repository"
fi

# --- 8. gh-dash is installed ------------------------------------------------

# -d: the folder exists.
if [ ! -d "$data_dir/gh/extensions/gh-dash" ]; then
  fail "gh-dash is not installed"
fi

# --- 9. The system's zsh is the login shell, where setup may use sudo -------

# Setup only changes the login shell where you answered yes to "Use sudo on
# this machine"; elsewhere install.sh lists it as a step for an administrator.
# As in check 4, chezmoi fills in a template: .useSudo is that answer (true or
# false), and .chezmoi.os is darwin on macOS. (dscl and getent look up the
# login shell, as in the setup script.)
if [ "$(chezmoi execute-template '{{ .useSudo }}')" = true ]; then
  if [ "$(chezmoi execute-template '{{ .chezmoi.os }}')" = darwin ]; then
    login_shell=$(dscl . -read "/Users/$(id -un)" UserShell | awk '{print $2}')
    expected=/bin/zsh
  else
    login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
    expected=/usr/bin/zsh
  fi

  if [ "$login_shell" != "$expected" ]; then
    fail "the login shell is $login_shell, not the system's zsh ($expected)"
  fi
fi

echo "Install checks passed (Homebrew in $brew_prefix)."
