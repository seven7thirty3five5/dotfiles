#!/bin/sh
# Remove the dotfiles setup, Homebrew, tool data and bootstrap prerequisites.
# Run as your normal user: sh uninstall.sh [--dry-run | --yes].
set -eu
umask 077

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: sh uninstall.sh [--dry-run] [--yes] [--prefix PATH]

Remove all managed dotfiles, tool configuration/data/history/credentials, chezmoi's
repository/state, Homebrew and its packages/casks, and bootstrap prerequisites.
macOS uses /bin/zsh; Linux switches to /bin/bash. Existing setup is not restored.

  --dry-run     Print the removal plan without changing anything.
  --yes         Confirm removal without an interactive prompt.
  --prefix PATH Remove one supported Homebrew prefix instead of every supported
                prefix. macOS accepts only /opt/homebrew; Linux also accepts
                /home/linuxbrew/.linuxbrew, ~/.linuxbrew and ~/.brew.
HELP
}

dry_run=false
confirmed=false
selected_prefix=
while [ "$#" -gt 0 ]; do
  case $1 in
    --dry-run) dry_run=true ;;
    --yes) confirmed=true ;;
    --prefix) [ "$#" -ge 2 ] || fail '--prefix needs a path'; selected_prefix=$2; shift ;;
    --prefix=*) selected_prefix=${1#*=} ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

uninstall_home=${HOME:?HOME is required}
case $uninstall_home in /|/home|/Users|/root/..|/usr|/opt|'') fail 'unsafe HOME' ;; /*) ;; *) fail 'HOME must be absolute' ;; esac
[ -d "$uninstall_home" ] || fail 'HOME does not exist'
[ ! -L "$uninstall_home" ] || fail 'HOME must not be a symlink'
cd "$uninstall_home"

path_syntax() {
  case $1 in
    *'/../'*|*'/./'*|*/..|*/.|*'//'*|*/|*'
'*) fail "unsafe path: $1" ;;
    /*) ;;
    *) fail "path must be absolute: $1" ;;
  esac
}
path_syntax "$uninstall_home"
home_path() {
  path_syntax "$1"
  case $1 in "$uninstall_home"/*) ;; *) fail "refusing a path outside HOME: $1" ;; esac
  # Never follow a symlink in a parent into someone else's configuration/data.
  checked_parent=${1%/*}
  while [ "$checked_parent" != "$uninstall_home" ]; do
    [ ! -L "$checked_parent" ] || fail "symlink parent must be removed explicitly: $checked_parent"
    checked_parent=${checked_parent%/*}
  done
}

config_root=${XDG_CONFIG_HOME:-$uninstall_home/.config}
data_root=${XDG_DATA_HOME:-$uninstall_home/.local/share}
state_root=${XDG_STATE_HOME:-$uninstall_home/.local/state}
cache_root=${XDG_CACHE_HOME:-$uninstall_home/.cache}
for root in "$config_root" "$data_root" "$state_root" "$cache_root"; do home_path "$root"; done
install_state=$state_root/dotfiles-bootstrap
home_path "$install_state"

case $(uname -s) in
  Darwin) platform=darwin; target_shell=/bin/zsh ;;
  Linux) platform=linux; target_shell=/bin/bash ;;
  *) fail 'only macOS and Linux are supported' ;;
esac
validate_prefix() {
  path_syntax "$1"
  if [ "$platform" = darwin ]; then
    [ "$1" = /opt/homebrew ] || fail 'macOS supports only /opt/homebrew'
  else
    case $1 in /home/linuxbrew/.linuxbrew|"$uninstall_home/.linuxbrew"|"$uninstall_home/.brew") ;;
      *) fail "unsupported Homebrew prefix: $1" ;;
    esac
  fi
}
[ -z "$selected_prefix" ] || validate_prefix "$selected_prefix"

# Put the plan outside every cleanup target. No network or Homebrew dependency is
# needed to remove a partial installation or to run the uninstaller a second time.
temporary=$(mktemp -d /tmp/dotfiles-uninstall.XXXXXX)
trap '/bin/rm -f "$temporary/plan" "$temporary/managed" "$temporary/casks" "$temporary/receipts" "$temporary/packages" "$temporary/installed" "$temporary/hosts" "$temporary/accounts" "$temporary/services" "$temporary/query-state.boltdb"; /bin/rm -rf "$temporary/gh" "$temporary/query-cache"; /bin/rmdir "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
for list in plan managed casks receipts packages installed hosts accounts services; do : > "$temporary/$list"; done

setup_exists=false
if [ -d "$data_root/chezmoi" ] || [ -f "$config_root/homebrew/Brewfile" ] || [ -d "$install_state" ]; then setup_exists=true; fi

queue() {
  queued=$1
  path_syntax "$queued"
  # Already removing an enclosing tree; do not inspect children of its symlinks.
  while IFS= read -r ancestor; do
    case $queued in "$ancestor"|"$ancestor"/*) return 0 ;; esac
  done < "$temporary/plan"
  case $queued in
    "$uninstall_home"/*) home_path "$queued" ;;
    /opt/homebrew|/home/linuxbrew/.linuxbrew|/Library/Developer/CommandLineTools|/Library/Caches/Homebrew|/Applications/Ghostty.app|/etc/paths.d/homebrew|/Library/LaunchAgents/homebrew.*.plist|/Library/LaunchDaemons/homebrew.*.plist|/etc/systemd/system/homebrew.*.service) ;;
    /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress|/tmp/dotfiles-install.*) ;;
    *) fail "refusing unexpected system path: $queued" ;;
  esac
  for protected in "$uninstall_home" "$config_root" "$data_root" "$state_root" "$cache_root"; do
    case $protected in "$queued"|"$queued"/*) fail "refusing to remove a base directory: $queued" ;; esac
  done
  case $install_state in "$queued"/*) fail "cleanup target contains the uninstall inventory: $queued" ;; esac
  if [ -e "$queued" ] || [ -L "$queued" ]; then printf '%s\n' "$queued" >> "$temporary/plan"; fi
}

# Defaults also handle installations made before install.sh recorded an inventory.
# Remove only tool-specific trees, never all of .config/.local/Library or HOME.
tools='ast-grep atuin bat btop chezmoi delta difftastic duf dust eza fd fzf gh gh-dash ghostty git glow herdr homebrew hyperfine lazydocker lazygit mole nvim ripgrep starship superfile yq zoxide zsh'
for root in "$config_root" "$uninstall_home/.config" "$data_root" "$state_root" "$cache_root"; do
  for tool in $tools; do queue "$root/$tool"; done
done
for field in xdg-config xdg-data xdg-state xdg-cache; do
  if [ -f "$install_state/$field" ]; then
    recorded_root=$(cat "$install_state/$field")
    home_path "$recorded_root"
    for tool in $tools; do queue "$recorded_root/$tool"; done
  fi
done
for artifact in .zshenv .zshrc .zprofile .zlogin .zlogout .editorconfig .hushlogin .zsh_history .zsh_sessions .gitconfig .git-credentials .local/bin/chezmoi bin/chezmoi; do
  queue "$uninstall_home/$artifact"
done
for artifact in "${GH_CONFIG_DIR:-$config_root/gh}" "${GH_DATA_DIR:-$data_root/gh}" \
  "${BAT_CONFIG_DIR:-$config_root/bat}" "${EZA_CONFIG_DIR:-$config_root/eza}" \
  "${_ZO_DATA_DIR:-$data_root/zoxide}"; do queue "$artifact"; done
for field in GH_CONFIG_DIR GH_DATA_DIR BAT_CONFIG_DIR EZA_CONFIG_DIR _ZO_DATA_DIR HOMEBREW_CACHE HOMEBREW_LOGS; do
  if [ -f "$install_state/path-$field" ]; then queue "$(cat "$install_state/path-$field")"; fi
done

source_root=$data_root/chezmoi
if [ -f "$install_state/workingTree" ]; then source_root=$(cat "$install_state/workingTree"); fi
home_path "$source_root"
for field in workingTree cacheDir configFile; do
  if [ -f "$install_state/$field" ]; then queue "$(cat "$install_state/$field")"; fi
done
queue "$source_root"
for field in persistent-state temporary-directory; do
  if [ -s "$install_state/$field" ]; then queue "$(cat "$install_state/$field")"; fi
done

if [ -f "$install_state/managed-files" ]; then cat "$install_state/managed-files" >> "$temporary/managed"; fi
chezmoi=$(command -v chezmoi || true)
if [ -n "$chezmoi" ] && [ -f "$source_root/.chezmoiroot" ]; then
  # Queries only: never destroy/forget targets in the source or auto-push edits.
  query_config=${XDG_CONFIG_HOME:-$uninstall_home/.config}/chezmoi/chezmoi.toml
  if [ -f "$install_state/configFile" ]; then query_config=$(cat "$install_state/configFile"); fi
  if ! "$chezmoi" --source "$source_root" --destination "$uninstall_home" --config "$query_config" \
    --persistent-state "$temporary/query-state.boltdb" --cache "$temporary/query-cache" \
    --no-pager --refresh-externals=never managed --include=files,symlinks \
    --path-style=absolute >> "$temporary/managed"; then
    [ -f "$install_state/managed-files" ] || fail 'cannot inventory managed files'
  fi
fi
while IFS= read -r artifact; do [ -z "$artifact" ] || queue "$artifact"; done < "$temporary/managed"

brew=
add_prefix() {
  validate_prefix "$1"
  if [ -e "$1" ] || [ -L "$1" ]; then setup_exists=true; fi
  if [ -x "$1/bin/brew" ] && [ -z "$brew" ]; then brew=$1/bin/brew; fi
  queue "$1"
}
if [ -n "$selected_prefix" ]; then add_prefix "$selected_prefix"
elif [ "$platform" = darwin ]; then add_prefix /opt/homebrew
else
  add_prefix /home/linuxbrew/.linuxbrew
  add_prefix "$uninstall_home/.linuxbrew"
  add_prefix "$uninstall_home/.brew"
fi
for artifact in "$cache_root/Homebrew" "$data_root/Homebrew" \
  "$uninstall_home/.cache/Homebrew" "$uninstall_home/Library/Caches/Homebrew" \
  "$uninstall_home/Library/Logs/Homebrew"; do queue "$artifact"; done
for artifact in "${HOMEBREW_CACHE:-$cache_root/Homebrew}" "${HOMEBREW_LOGS:-$cache_root/Homebrew/Logs}"; do queue "$artifact"; done

selected_tools=
if [ "$platform" = darwin ]; then
  selected_tools=$(xcode-select --print-path 2>/dev/null || true)
  queue /Library/Caches/Homebrew
  queue /Library/Developer/CommandLineTools
  queue /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  queue /Applications/Ghostty.app
  queue "$uninstall_home/Applications/Ghostty.app"
  for tool in $tools; do
    for root in 'Application Support' Caches Logs; do queue "$uninstall_home/Library/$root/$tool"; done
  done
  for artifact in 'Application Support/com.mitchellh.ghostty' Caches/com.mitchellh.ghostty \
    HTTPStorages/com.mitchellh.ghostty Preferences/com.mitchellh.ghostty.plist \
    'Saved Application State/com.mitchellh.ghostty.savedState' WebKit/com.mitchellh.ghostty; do
    queue "$uninstall_home/Library/$artifact"
  done
  if [ -f /etc/paths.d/homebrew ] && grep -Fxq /opt/homebrew/bin /etc/paths.d/homebrew; then queue /etc/paths.d/homebrew; fi
  if command -v pkgutil >/dev/null 2>&1; then
    pkgutil --pkgs | awk '/^com\.apple\.pkg\.CLTools/ { print }' > "$temporary/receipts"
  fi
  if [ -n "$brew" ]; then
    if ! HOMEBREW_NO_AUTO_UPDATE=1 "$brew" list --cask > "$temporary/casks"; then
      # Ghostty has an explicit removal plan even with a broken Homebrew binary.
      : > "$temporary/casks"
      for cask in /opt/homebrew/Caskroom/*; do
        [ ! -d "$cask" ] || printf '%s\n' "${cask##*/}" >> "$temporary/casks"
      done
    fi
  fi
fi

# Units are removed even when their Homebrew installation is already gone.
for directory in "$uninstall_home/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons \
  "$config_root/systemd/user" /etc/systemd/system; do
  for service in "$directory"/homebrew.*.plist "$directory"/homebrew.*.service; do
    [ -e "$service" ] || [ -L "$service" ] || continue
    if [ -z "$selected_prefix" ] || grep -Fq "$selected_prefix/" "$service"; then
      queue "$service"
      printf '%s\n' "$service" >> "$temporary/services"
    fi
  done
done

# Read account names only, without an auth status request or exposing stored tokens.
# gh logout removes local credentials, not remote OAuth grants.
gh=
[ -z "$brew" ] || { [ ! -x "${brew%/brew}/gh" ] || gh=${brew%/brew}/gh; }
[ -n "$gh" ] || gh=$(command -v gh || true)
gh_config=${GH_CONFIG_DIR:-$config_root/gh}
if [ -z "${GH_CONFIG_DIR:-}" ] && [ -f "$install_state/path-GH_CONFIG_DIR" ]; then
  gh_config=$(cat "$install_state/path-GH_CONFIG_DIR")
fi
gh_clean() {
  env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN \
    GH_CONFIG_DIR="$gh_config" "$gh" "$@"
}
printf '%s\n' github.com > "$temporary/hosts"
if [ -f "$gh_config/hosts.yml" ]; then
  awk '/^[[:alnum:].-]+:$/ { sub(/:$/, ""); print }' \
    "$gh_config/hosts.yml" >> "$temporary/hosts"
  awk '
    /^[[:alnum:].-]+:$/ { host = $0; sub(/:$/, "", host); users = 0; next }
    /^[ ]+users:$/ { users = match($0, /[^ ]/); next }
    /^[ ]+user: / { if (host != "") print host "\t" $2; users = 0; next }
    /^[ ]+[[:alnum:]-]+: *(\{\})?$/ {
      indent = match($0, /[^ ]/)
      if (users && indent > users) { name = $1; sub(/:$/, "", name); print host "\t" name }
      else if (users && indent <= users) users = 0
    }
  ' "$gh_config/hosts.yml" | LC_ALL=C sort -u > "$temporary/accounts"
fi
has_credentials=false
if [ -s "$temporary/accounts" ]; then has_credentials=true; fi
if [ "$platform" = darwin ] && command -v security >/dev/null 2>&1; then
  while IFS= read -r host; do
    if security find-generic-password -s "gh:$host" >/dev/null 2>&1; then has_credentials=true; fi
  done < "$temporary/hosts"
fi

manager=none
legacy_packages=false
if [ "$platform" = linux ]; then
  if [ -f "$install_state/prerequisites-manager" ]; then
    manager=$(cat "$install_state/prerequisites-manager")
    if [ "$manager" != none ] && [ -f "$install_state/prerequisites-packages" ]; then
      cat "$install_state/prerequisites-packages" > "$temporary/packages"
    fi
    if [ -f "$install_state/legacy-prerequisites" ]; then
      manager=$(cat "$install_state/legacy-prerequisites")
      legacy_packages=true
    fi
  elif $setup_exists && { [ -z "$selected_prefix" ] || [ "$selected_prefix" = /home/linuxbrew/.linuxbrew ]; }; then
    # Older installs lack provenance: remove the prerequisites named by bootstrap.
    legacy_packages=true
    if command -v apt-get >/dev/null 2>&1; then
      manager=apt
    elif command -v dnf >/dev/null 2>&1; then
      manager=dnf
    elif command -v pacman >/dev/null 2>&1; then
      manager=pacman
    fi
  fi
fi
case $manager in none|apt|dnf|pacman) ;; *) fail 'invalid prerequisite package manager' ;; esac
remove_group=false
if [ "$manager" = dnf ] && { $legacy_packages || [ -f "$install_state/prerequisites-group" ]; }; then
  installed_groups=$(dnf --cacheonly group list --installed --ids)
  if printf '%s\n' "$installed_groups" | grep -Eq 'development-tools|Development Tools'; then remove_group=true; fi
fi
if $legacy_packages; then
  case $manager in
    apt) printf '%s\n' build-essential procps curl file git ca-certificates zsh unzip >> "$temporary/packages" ;;
    dnf) printf '%s\n' procps-ng curl file git zsh unzip >> "$temporary/packages" ;;
    pacman) printf '%s\n' base-devel procps-ng curl file git zsh unzip >> "$temporary/packages" ;;
  esac
fi
while IFS= read -r package; do
  printf '%s\n' "$package" | grep -Eq '^[[:alnum:]][[:alnum:]+_.:@-]*$' || fail 'invalid prerequisite package name'
done < "$temporary/packages"
# Ignore packages already removed on an interrupted or repeated uninstall.
case $manager in
  apt) dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' |
    awk '$2 == "installed" { print $1 }' > "$temporary/installed" ;;
  dnf) rpm -qa --qf '%{NAME}\n' > "$temporary/installed" ;;
  pacman) pacman -Qq > "$temporary/installed" ;;
esac
if [ "$manager" != none ]; then
  # grep's status 1 means the requested packages are all absent.
  grep -Fx -f "$temporary/packages" "$temporary/installed" > "$temporary/managed" || [ "$?" -eq 1 ]
  mv "$temporary/managed" "$temporary/packages"
fi
queue "$install_state"

current_shell=
user_name=$(id -un)
if [ "$platform" = darwin ]; then
  current_shell=$(dscl . -read "/Users/$user_name" UserShell | awk '{print $2}')
else
  current_shell=$(getent passwd "$user_name" | cut -d: -f7)
fi
[ -n "$current_shell" ] || fail 'cannot determine the current login shell'
[ -x "$target_shell" ] || fail "required login shell is missing: $target_shell"

printf '%s\n' 'Removal plan (includes packages, personal tool data, histories and local credentials):'
cat "$temporary/plan"
if [ -s "$temporary/casks" ]; then printf 'Homebrew casks to uninstall and zap:\n'; cat "$temporary/casks"; fi
if [ -s "$temporary/packages" ]; then printf 'System prerequisite packages to remove (%s):\n' "$manager"; cat "$temporary/packages"; fi
if $remove_group; then printf '%s\n' 'System prerequisite group to remove: Development Tools'; fi
if [ -s "$temporary/receipts" ]; then printf 'Command Line Tools receipts to forget:\n'; cat "$temporary/receipts"; fi
if [ "$current_shell" != "$target_shell" ]; then printf 'Login shell: %s -> %s\n' "$current_shell" "$target_shell"; fi
if $has_credentials; then printf '%s\n' 'Remove local GitHub CLI credentials.'; fi
if $dry_run; then exit 0; fi
if [ ! -s "$temporary/plan" ] && [ ! -s "$temporary/packages" ] && [ ! -s "$temporary/receipts" ] \
  && [ "$current_shell" = "$target_shell" ] && ! $has_credentials && ! $remove_group; then
  printf '%s\n' 'Already uninstalled.'
  exit 0
fi
if ! $confirmed; then
  [ -t 0 ] || fail 'use --yes to confirm removal, or --dry-run to review it'
  printf 'Permanently remove this setup and its data? [y/N] '
  read -r answer
  case $answer in y|Y|yes) ;; *) printf '%s\n' 'Cancelled.'; exit 0 ;; esac
fi

need_sudo=false
while IFS= read -r artifact; do
  [ -w "${artifact%/*}" ] || need_sudo=true
done < "$temporary/plan"
[ ! -s "$temporary/packages" ] && [ ! -s "$temporary/receipts" ] || need_sudo=true
if $remove_group; then need_sudo=true; fi
if $need_sudo && [ "$(id -u)" -ne 0 ]; then
  [ -x /usr/bin/sudo ] || fail 'sudo is needed to complete removal'
  /usr/bin/sudo -v || fail 'sudo access is needed to complete removal'
fi
privileged() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else /usr/bin/sudo "$@"; fi
}

# Switch away from shells in a prefix that is about to disappear.
if [ "$current_shell" != "$target_shell" ]; then
  if $need_sudo || [ "$(id -u)" -eq 0 ]; then
    privileged chsh -s "$target_shell" "$user_name"
  elif [ -x /usr/bin/sudo ] && /usr/bin/sudo -n -v >/dev/null 2>&1; then
    privileged chsh -s "$target_shell" "$user_name"
  else
    chsh -s "$target_shell"
  fi
fi
while IFS= read -r service; do
  unit=${service##*/}
  case $service in
    */LaunchDaemons/*) privileged launchctl bootout "system/${unit%.plist}" >/dev/null 2>&1 || true ;;
    */LaunchAgents/*) launchctl bootout "gui/$(id -u)/${unit%.plist}" >/dev/null 2>&1 || true ;;
    /etc/systemd/*) privileged systemctl disable --now "$unit" ;;
    *) systemctl --user disable --now "$unit" ;;
  esac
done < "$temporary/services"
tab=$(printf '\t')
if [ -n "$gh" ]; then
  # Isolate each account so gh deletes its named keyring entry as well as the
  # active entry. Some gh versions leave named entries when logging out of a
  # config that still contains multiple accounts. No tokens are copied here.
  gh_config=$temporary/gh
  mkdir -p "$gh_config"
  while IFS="$tab" read -r host account; do
    [ -n "$host" ] || continue
    printf '%s:\n    user: %s\n    users:\n        %s:\n' "$host" "$account" "$account" > "$gh_config/hosts.yml"
    gh_clean auth logout --hostname "$host" --user "$account"
  done < "$temporary/accounts"
fi
if [ "$platform" = darwin ] && command -v security >/dev/null 2>&1; then
  while IFS= read -r host; do
    # Also remove keychain credentials when the gh binary/config is already gone.
    while security delete-generic-password -s "gh:$host" >/dev/null 2>&1; do :; done
  done < "$temporary/hosts"
elif [ "$platform" = linux ] && command -v secret-tool >/dev/null 2>&1; then
  while IFS= read -r host; do
    secret-tool clear service "gh:$host" >/dev/null 2>&1 || true
  done < "$temporary/hosts"
fi
while IFS= read -r cask; do
  # Ghostty's app/data are explicitly queued. Its cask's quit hook could kill the
  # terminal running this script before the rest of the teardown completes.
  case $cask in ''|ghostty) continue ;; esac
  HOMEBREW_NO_AUTO_UPDATE=1 "$brew" uninstall --cask --force --zap --ignore-dependencies "$cask"
done < "$temporary/casks"

while IFS= read -r artifact; do
  [ "$artifact" != "$install_state" ] || continue
  [ -e "$artifact" ] || [ -L "$artifact" ] || continue
  # Validated above; rm unlinks a final symlink rather than following its target.
  if ! /bin/rm -rf -- "$artifact"; then privileged /bin/rm -rf -- "$artifact"; fi
done < "$temporary/plan"
if [ "$platform" = darwin ]; then
  while IFS= read -r receipt; do privileged pkgutil --forget "$receipt"; done < "$temporary/receipts"
  case $selected_tools in /Library/Developer/CommandLineTools*) privileged xcode-select --reset ;; esac
fi

# The interpreter and /bin/bash are OS tools, not bootstrap prerequisites. Remove
# packages last, after commands supplied by those packages are no longer needed.
set --
while IFS= read -r package; do set -- "$@" "$package"; done < "$temporary/packages"
if $remove_group; then privileged dnf group remove -y 'Development Tools'; fi
if [ "$#" -gt 0 ]; then
  case $manager in
    apt)
      if $legacy_packages; then privileged apt-get purge --auto-remove -y "$@"
      else privileged apt-get purge -y "$@"
      fi
      ;;
    dnf) privileged dnf remove -y "$@" ;;
    pacman) privileged pacman -Rns --noconfirm "$@" ;;
  esac
fi

# Keep the inventory until every privileged operation succeeds, so failures can be
# retried even after the repository, chezmoi executable and Homebrew are gone.
/bin/rm -rf -- "$install_state"
for directory in "$config_root" "$data_root" "$state_root" "$cache_root" "$uninstall_home/.local/share" \
  "$uninstall_home/.local/state" "$uninstall_home/.local/bin" "$uninstall_home/.local" "$uninstall_home/Applications"; do
  /bin/rmdir "$directory" 2>/dev/null || true
done
if [ "$platform" = linux ] && [ ! -e /home/linuxbrew/.linuxbrew ]; then
  if [ -d /home/linuxbrew ]; then privileged /bin/rmdir /home/linuxbrew 2>/dev/null || true; fi
fi
printf '%s\n' 'Uninstalled. Open a new terminal.'
