#!/bin/sh
# Set up a new macOS or Linux machine with these dotfiles in one command:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
#
# `chezmoi apply` does the work: the scripts in home/.chezmoiscripts install
# Homebrew (/opt/homebrew on macOS; a prefix chosen by sudo access on Linux),
# the Brewfile, gh-dash and LazyVim's plugins, and make zsh the login shell.
# `chezmoi init` then runs once more because
# chezmoi's own config looks for delta and nvim, which did not exist the first time,
# and a chezmoi script cannot run chezmoi itself.
#
# Arguments are passed to `chezmoi init` (e.g. --branch). Re-running is safe:
# an existing ~/.local/share/chezmoi is reused, not cloned again.
set -eu

install_umask=$(umask)
umask 077
install_state=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-bootstrap
case $install_state in
  *'/../'*|*'/./'*|*/..|*/.|*'//'*) echo "error: unsafe XDG_STATE_HOME." >&2; exit 1 ;;
  "$HOME"/*) ;;
  *) echo "error: XDG_STATE_HOME must be inside your home directory." >&2; exit 1 ;;
esac
checked_parent=$install_state
while [ "$checked_parent" != "$HOME" ]; do
  if [ -L "$checked_parent" ]; then
    echo "error: bootstrap state must not traverse a symlink: $checked_parent" >&2
    exit 1
  fi
  checked_parent=${checked_parent%/*}
done
mkdir -p "$install_state"
umask "$install_umask"

# Snapshot this run, then accumulate only dependencies installed by bootstrap.
# Packages installed separately between repeat installs are not adopted.
package_list() {
  case $1 in
    apt) dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' |
      awk '$2 == "installed" { print $1 }' | LC_ALL=C sort -u ;;
    dnf) rpm -qa --qf '%{NAME}\n' | LC_ALL=C sort -u ;;
    pacman) pacman -Qq | LC_ALL=C sort -u ;;
  esac
}
manager=none
if [ "$(uname -s)" = Linux ]; then
  if command -v apt-get >/dev/null 2>&1; then manager=apt
  elif command -v dnf >/dev/null 2>&1; then manager=dnf
  elif command -v pacman >/dev/null 2>&1; then manager=pacman
  fi
fi
if [ "$manager" != none ]; then
  package_list "$manager" > "$install_state/packages-before"
fi
if [ ! -f "$install_state/prerequisites-manager" ]; then
  printf '%s\n' none > "$install_state/prerequisites-manager"
  if [ "$manager" != none ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ] \
    && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/homebrew/Brewfile" ]; then
    # A pre-inventory sudo bootstrap already installed its distro prerequisites.
    printf '%s\n' "$manager" > "$install_state/legacy-prerequisites"
  fi
fi
record_packages() {
  if [ "$manager" != none ] && [ -f "$install_state/packages-before" ] \
    && [ "$(cat "$install_state/prerequisites-manager")" != none ]; then
    package_list "$manager" > "$install_state/packages-after"
    LC_ALL=C comm -13 "$install_state/packages-before" "$install_state/packages-after" \
      > "$install_state/prerequisites-packages.tmp"
    if [ -f "$install_state/prerequisites-packages" ]; then
      cat "$install_state/prerequisites-packages" >> "$install_state/prerequisites-packages.tmp"
    fi
    LC_ALL=C sort -u "$install_state/prerequisites-packages.tmp" > "$install_state/prerequisites-packages.sorted"
    mv "$install_state/prerequisites-packages.sorted" "$install_state/prerequisites-packages"
    rm -f "$install_state/prerequisites-packages.tmp"
  fi
}

tmpdir=$(mktemp -d /tmp/dotfiles-install.XXXXXX)
printf '%s\n' "$tmpdir" > "$install_state/temporary-directory"
cleanup() {
  status=$?
  trap - EXIT
  record_packages || status=1
  rm -f "$tmpdir/chezmoi" "$tmpdir/managed-files"
  rmdir "$tmpdir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# A local copy can be installed again after uninstall removed system curl on Linux.
if ! command -v curl >/dev/null 2>&1 && [ "$manager" != none ]; then
  printf '%s\n' "$manager" > "$install_state/prerequisites-manager"
  case $manager in
    apt) sudo apt-get update; sudo apt-get install --no-install-recommends -y curl ca-certificates ;;
    dnf) sudo dnf install -y curl ca-certificates ;;
    pacman) sudo pacman -S --needed --noconfirm curl ca-certificates ;;
  esac
fi

if command -v chezmoi >/dev/null 2>&1; then
  chezmoi=$(command -v chezmoi)
else
  # A temporary copy only; the Brewfile installs chezmoi with Homebrew for everyday use.
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$tmpdir"
  chezmoi=$tmpdir/chezmoi
fi

# The built-in Git client can clone before Homebrew supplies Git or macOS CLT.
"$chezmoi" init --use-builtin-git=true "$@" seven7thirty3five5

# init accepts flags such as --branch that other commands do not. Forward its
# global path/data overrides to queries so alternate sources and configs work too.
query_chezmoi() {
  query=$1
  shift
  pending=$#
  if [ "$query" = managed ]; then
    set -- "$@" managed --include=files,symlinks --path-style=absolute
  else
    set -- "$@" execute-template "$query"
  fi
  while [ "$pending" -gt 0 ]; do
    option=$1
    shift
    pending=$((pending - 1))
    case $option in
      -S|--source|-D|--destination|-c|--config|--cache|--persistent-state|-W|--working-tree|--override-data|--override-data-file)
        value=$1; shift; pending=$((pending - 1))
        set -- "$@" "$option" "$value"
        ;;
      -C|--config-path)
        value=$1; shift; pending=$((pending - 1))
        set -- "$@" --config "$value"
        ;;
      --source=*|--destination=*|--config=*|--cache=*|--persistent-state=*|--working-tree=*|--override-data=*|--override-data-file=*)
        set -- "$@" "$option"
        ;;
      --config-path=*) set -- "$@" "--config=${option#*=}" ;;
    esac
  done
  "$chezmoi" --use-builtin-git=true --no-pager --refresh-externals=never "$@"
}

record_targets() {
  query_chezmoi managed "$@" > "$tmpdir/managed-files"
  if [ -f "$install_state/managed-files" ]; then
    cat "$install_state/managed-files" >> "$tmpdir/managed-files"
  fi
  LC_ALL=C sort -u "$tmpdir/managed-files" > "$install_state/managed-files.tmp"
  mv "$install_state/managed-files.tmp" "$install_state/managed-files"
  for field in workingTree configFile cacheDir destDir; do
    query_chezmoi "{{ .chezmoi.$field }}" "$@" > "$install_state/$field"
  done
  query_chezmoi '{{ .chezmoi.config.persistentState }}' "$@" > "$install_state/persistent-state"
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}" > "$install_state/xdg-config"
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}" > "$install_state/xdg-data"
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}" > "$install_state/xdg-state"
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}" > "$install_state/xdg-cache"
  for field in GH_CONFIG_DIR GH_DATA_DIR BAT_CONFIG_DIR EZA_CONFIG_DIR _ZO_DATA_DIR HOMEBREW_CACHE HOMEBREW_LOGS; do
    value=$(printenv "$field" || true)
    if [ -n "$value" ]; then printf '%s\n' "$value" > "$install_state/path-$field"; fi
  done
}

# Save the targets before applying them, including when a later install hook fails.
record_targets "$@"
"$chezmoi" init --use-builtin-git=true --apply "$@"

# The install scripts run in child processes; their PATH changes cannot reach this
# shell. Initialize the detected Homebrew here so the second init finds delta and
# nvim, including on Linux where .zshrc only runs in interactive shells.
prefix=$(query_chezmoi '{{ includeTemplate "brew-prefix" . }}' "$@")
if [ -z "$prefix" ] || [ ! -x "$prefix/bin/brew" ]; then
  echo "error: Homebrew not found after applying the dotfiles." >&2
  exit 1
fi
brew_env=$("$prefix/bin/brew" shellenv sh)
eval "$brew_env"
"$chezmoi" init "$@"

# Merge inventories so targets removed from a later revision remain removable.
record_targets "$@"
printf '%s\n' "$prefix" > "$install_state/homebrew-prefix"

echo "Done. Open a new terminal to start using the new setup."
