#!/bin/sh
# Check a machine that install.sh has just set up.
# The Bootstrap workflow runs this as the user who ran install.sh.
set -eu

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Use the PATH the dotfiles give an interactive login zsh. On Linux, Homebrew is
# only set up in .zshrc, which other shells never read.
PATH=$(zsh -lic 'print -r -- "$PATH"' 2>/dev/null | tail -n 1)
export PATH

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
data_dir=${XDG_DATA_HOME:-$HOME/.local/share}

# 1. The Brewfile's tools are on PATH.
for tool in brew chezmoi git delta difft nvim fzf fd rg bat eza \
  atuin zoxide starship lazygit gh; do
  command -v "$tool" >/dev/null || fail "$tool is not on PATH"
done

# 2. Every deployed file matches the repository. Scripts are left out because
#    the LazyVim script runs again whenever lazy.nvim updates lazy-lock.json.
if ! chezmoi verify --exclude=scripts; then
  chezmoi diff --no-pager --exclude=scripts >&2
  fail "deployed files differ from the repository"
fi

# 3. The templates found Homebrew where it was installed.
template_prefix=$(chezmoi execute-template '{{ includeTemplate "brew-prefix" . }}')
brew_prefix=$(brew --prefix)
if [ "$template_prefix" != "$brew_prefix" ]; then
  fail "brew-prefix found $template_prefix, but Homebrew is in $brew_prefix"
fi

# 4. The git config was applied.
if [ "$(git config --get diff.algorithm)" != histogram ]; then
  fail "the git config was not applied"
fi

# 5. install.sh's second `chezmoi init` found delta, so chezmoi's config has a pager.
if ! grep -q '^\[diff\]' "$config_dir/chezmoi/chezmoi.toml"; then
  fail "chezmoi's config has no [diff] pager; the second chezmoi init did not run"
fi

# 6. lazy-lock.json and gh's config.yml are symlinks into the repository.
for file in "$config_dir/nvim/lazy-lock.json" "$config_dir/gh/config.yml"; do
  [ -L "$file" ] || fail "$file is not a symlink into the repository"
done

# 7. gh-dash and LazyVim's plugins are installed.
[ -d "$data_dir/gh/extensions/gh-dash" ] || fail "gh-dash is not installed"
[ -d "$data_dir/nvim/lazy/LazyVim" ] || fail "LazyVim's plugins are not installed"

echo "Install checks passed (Homebrew in $brew_prefix)."
