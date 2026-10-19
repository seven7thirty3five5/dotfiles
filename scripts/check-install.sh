#!/bin/sh
#
# check-install.sh: check that install.sh set up this machine. CI runs it after
# install.sh. On your own machine, it needs a clean repository.

set -eu

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

chezmoi=$HOME/.local/bin/chezmoi
[ -x "$chezmoi" ] || fail "chezmoi is not in ~/.local/bin"
prefix=$("$chezmoi" execute-template '{{ includeTemplate "brew-prefix" . | trim }}')
[ -x "$prefix/bin/fish" ] || fail "Homebrew's fish is not in $prefix/bin"

# Start fish the way herdr's panes do on macOS, and use its PATH from here on.
# It must print nothing else, because startup output breaks scp, rsync and git
# over SSH, and it must put ~/.local/bin before Homebrew.
# shellcheck disable=SC2016
startup=$("$prefix/bin/fish" --login --interactive -c '
    set -l local_bin (contains --index -- $HOME/.local/bin $PATH)
    set -l brew_bin (contains --index -- $HOMEBREW_PREFIX/bin $PATH)
    test -n "$local_bin" -a -n "$brew_bin"; and test $local_bin -lt $brew_bin; or exit 1
    printf "PATH=%s" (string join : -- $PATH)
' 2>&1 </dev/null) || fail "fish failed to start, or put Homebrew before ~/.local/bin: $startup"
case $startup in
  *"
"*) fail "fish printed more than its PATH: $startup" ;;
  PATH=*) PATH=${startup#PATH=} ;;
  *) fail "fish printed more than its PATH: $startup" ;;
esac
export PATH

[ "$(brew --prefix)" = "$prefix" ] || fail "Homebrew is in $(brew --prefix), not $prefix"

for tool in brew chezmoi mise node pnpm python uv git delta difft fresh micro fzf fd rg \
  bat eza atuin zoxide starship lazygit gh herdr shellcheck shfmt act actionlint; do
  command -v "$tool" >/dev/null || fail "$tool is not on fish's PATH"
done

# Every managed file matches the repository, and setup changed nothing in it.
if ! "$chezmoi" verify --exclude=scripts; then
  "$chezmoi" diff --no-pager --exclude=scripts >&2
  fail "deployed files differ from the repository"
fi
changes=$("$chezmoi" git -- status --porcelain)
[ -z "$changes" ] || fail "setup changed files in the repository: $changes"

# install.sh's last `chezmoi init` gave chezmoi delta as its diff pager.
grep -q '^\[diff\]' "$HOME/.config/chezmoi/chezmoi.toml" \
  || fail "chezmoi's config has no [diff] section"

# A login shell without Homebrew on its PATH starts herdr through ~/.local/bin.
env PATH="$HOME/.local/bin:/usr/bin:/bin" herdr --version >/dev/null \
  || fail "herdr doesn't run through ~/.local/bin"

echo "Install checks passed (Homebrew in $prefix)."
