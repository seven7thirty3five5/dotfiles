#!/bin/sh
# Run only on a disposable Linux machine/container, after install and check-install.
# The checkout must be outside ~/.local/share/chezmoi, which uninstall removes.
set -eu

checkout=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
case $checkout in "$HOME/.local/share/chezmoi"*) echo 'Use a separate checkout for this destructive test.' >&2; exit 1 ;; esac

sh "$HOME/.local/share/chezmoi/install.sh"
sh "$HOME/.local/share/chezmoi/scripts/check-install.sh"
sh "$checkout/uninstall.sh" --yes
sh "$checkout/uninstall.sh" --yes
for artifact in "$HOME/.local/share/chezmoi" "$HOME/.config/chezmoi" \
  "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/dotfiles-bootstrap" \
  "$HOME/.zshenv" "$HOME/.linuxbrew" "$HOME/.brew" /home/linuxbrew/.linuxbrew; do
  if [ -e "$artifact" ] || [ -L "$artifact" ]; then
    printf 'Cleanup left an artifact: %s\n' "$artifact" >&2
    exit 1
  fi
done
[ "$(getent passwd "$(id -un)" | cut -d: -f7)" = /bin/bash ]

# Reinstall from the same commit without depending on the deleted checkout/config.
mkdir -p "$HOME/.local/share/chezmoi" "$HOME/.config/chezmoi"
cp -R "$checkout/." "$HOME/.local/share/chezmoi/"
printf '[data]\ngitName = "CI"\ngitEmail = "ci@example.invalid"\npublishDotfiles = false\n' \
  > "$HOME/.config/chezmoi/chezmoi.toml"
sh "$HOME/.local/share/chezmoi/install.sh"
sh "$HOME/.local/share/chezmoi/scripts/check-install.sh"
sh "$checkout/uninstall.sh" --yes
sh "$checkout/uninstall.sh" --yes
printf '%s\n' 'Install/uninstall/reinstall cycle passed.'
