#!/bin/sh
# Check a machine that install.sh has just set up; the Bootstrap workflow runs this as
# the installing user. An interactive login zsh supplies PATH and Homebrew exactly as
# the dotfiles set them up (on Linux, Homebrew is initialized in .zshrc).
set -eu

exec zsh -lic '
fail() { print -ru2 -- "FAIL: $1"; exit 1; }

for tool in brew chezmoi git delta difft nvim fzf fd rg bat eza atuin zoxide starship lazygit gh; do
  (( $+commands[$tool] )) || fail "$tool is not on PATH"
done
# Files only: verify also counts scripts that would run again, and the LazyVim script
# re-runs whenever lazy.nvim updates lazy-lock.json (it adds newly enabled plugins).
if ! chezmoi verify --exclude=scripts; then
  chezmoi diff --no-pager --exclude=scripts >&2
  fail "deployed files differ from the source state (chezmoi verify)"
fi
prefix=$(chezmoi execute-template "{{ includeTemplate \"brew-prefix\" . }}")
[[ $prefix == $(brew --prefix) ]] || fail "the brew-prefix template found [$prefix], but brew is in $(brew --prefix)"
[[ $(git config --get diff.algorithm) == histogram ]] || fail "the git config was not applied"
grep -q "^\[diff\]" "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml" \
  || fail "chezmoi config has no delta pager; the second chezmoi init did not run"
[[ -L ~/.config/nvim/lazy-lock.json && -L ~/.config/gh/config.yml ]] \
  || fail "lazy-lock.json and gh config.yml are not symlinks into the repository"
[[ -d ${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-dash ]] || fail "gh-dash is not installed"
[[ -d ${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/LazyVim ]] || fail "LazyVim plugins are not installed"
print -r -- "install checks passed (Homebrew in $prefix)"
'
