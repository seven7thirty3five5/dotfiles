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

# chezmoi lives in ~/.local/bin, which isn't on this script's PATH yet.
chezmoi=$HOME/.local/bin/chezmoi
if [ ! -x "$chezmoi" ]; then
  fail "chezmoi is not installed in ~/.local/bin"
fi

# Ask chezmoi where Homebrew is: the brew-prefix template prints its folder, or
# nothing if Homebrew isn't installed. fish, the shell in herdr's panes, comes
# from there. (-n: the text isn't empty; -x: a program we can run.)
brew_prefix=$("$chezmoi" execute-template '{{ includeTemplate "brew-prefix" . }}')
if [ -z "$brew_prefix" ]; then
  fail "Homebrew is not installed"
fi

fish=$brew_prefix/bin/fish
if [ ! -x "$fish" ]; then
  fail "fish is not installed in $brew_prefix/bin"
fi

# Use the same PATH a herdr pane gets. We start fish as an interactive login
# shell (-l -i), the way herdr does on macOS, and have it print its PATH with
# colons between the folders (string join). Its startup messages, if any, are
# thrown away (2>/dev/null) and only the last line, the PATH itself, is kept
# (tail -n 1). The single quotes keep this shell from expanding $PATH itself.
# shellcheck disable=SC2016
PATH=$("$fish" -l -i -c 'string join : -- $PATH' 2>/dev/null </dev/null | tail -n 1)
export PATH

# Where the dotfiles keep config and data files. ${NAME:-default} means "the
# value of $NAME, or default when NAME isn't set".
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
data_dir=${XDG_DATA_HOME:-$HOME/.local/share}

# --- 1. The shell tools and runtimes are installed and on PATH -------------

# The loop goes through the list one word at a time. chezmoi and mise come
# from ~/.local/bin; mise provides node (with npm), pnpm, python and uv.
# All of them must resolve from fish's PATH, just as in a herdr pane.
tools="brew chezmoi mise node pnpm python uv git delta difft fresh micro fzf fd rg bat eza
       atuin zoxide starship lazygit gh herdr shellcheck shfmt act actionlint"
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
# (from the start of this script) with Homebrew's own.
if [ "$(brew --prefix)" != "$brew_prefix" ]; then
  fail "brew-prefix found $brew_prefix, but Homebrew is in $(brew --prefix)"
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

# --- 9. The login shell is the system's own, and it finds herdr ------------

# The login shells stay the system's: /bin/zsh on macOS and bash on Linux. Their
# one startup file puts Homebrew, and so herdr, on PATH: ~/.zprofile for a zsh
# login shell, ~/.bashrc for an interactive bash, which an SSH login reaches
# through the system's login file. dscl and getent look up the login shell, as
# in install.sh. (*/bash matches any path ending in /bash; </dev/null keeps the
# shells from waiting for input, and 2>/dev/null drops bash's warnings about
# having no terminal.)
if [ "$(chezmoi execute-template '{{ .chezmoi.os }}')" = darwin ]; then
  login_shell=$(dscl . -read "/Users/$(id -un)" UserShell | awk '{print $2}')
  if [ "$login_shell" != /bin/zsh ]; then
    fail "the login shell is $login_shell, not macOS's /bin/zsh"
  fi

  login_herdr=$(/bin/zsh -l -c 'command -v herdr' </dev/null)
else
  login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
  case $login_shell in
    */bash) ;;
    *) fail "the login shell is $login_shell, not the system's bash" ;;
  esac

  login_herdr=$(bash -l -i -c 'command -v herdr' </dev/null 2>/dev/null | tail -n 1)
fi

if [ "$login_herdr" != "$brew_prefix/bin/herdr" ]; then
  fail "the login shell finds herdr at '$login_herdr', not $brew_prefix/bin/herdr"
fi

# --- 10. herdr starts fish --------------------------------------------------

# herdr's config names fish's full path as the shell for new panes
# (default_shell), and runs both popups through it (command = "exec FISH -c
# ..."). sed -n prints only what its pattern captures; grep -c counts the
# matching lines.
herdr_config=$config_dir/herdr/config.toml
default_shell=$(sed -n 's/^default_shell = "\(.*\)"$/\1/p' "$herdr_config")
if [ "$default_shell" != "$fish" ] || [ ! -x "$default_shell" ]; then
  fail "herdr's default_shell is '$default_shell', not $fish"
fi

if [ "$(grep -c "^command = \"exec $fish -c " "$herdr_config")" -ne 2 ]; then
  fail "herdr's popup commands don't run through $fish"
fi

echo "Install checks passed (Homebrew in $brew_prefix)."
