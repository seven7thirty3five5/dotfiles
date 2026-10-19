#!/bin/sh
#
# lint.sh: check the shell scripts, fish files and workflows without running
# them. Needs chezmoi, shellcheck, fish and actionlint, which the Brewfile
# installs. CI runs it on every push.

set -eu
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# check_rendered TEMPLATE COMMAND...: run COMMAND on TEMPLATE as chezmoi writes
# it on this machine, once for each answer to "Use sudo on this machine".
check_rendered() {
  template=$1
  shift
  rendered=$tmp/$(basename "$template" .tmpl)
  for use_sudo in true false; do
    chezmoi --source . execute-template --override-data "{\"useSudo\": $use_sudo}" \
      <"$template" >"$rendered"
    "$@" "$rendered" || {
      echo "in $template, with useSudo = $use_sudo" >&2
      exit 1
    }
  done
}

shellcheck install.sh scripts/*.sh

# A setup script that comes out empty is one chezmoi skips on this machine.
for script in home/.chezmoiscripts/*; do
  case $script in
    *.tmpl) check_rendered "$script" shellcheck --shell=sh ;;
    *) shellcheck "$script" ;;
  esac
done

find home -name '*.fish' -o -name '*.fish.tmpl' | while read -r file; do
  case $file in
    *.tmpl) check_rendered "$file" fish --no-execute ;;
    *) fish --no-execute "$file" ;;
  esac
done

actionlint
echo "Lint passed."
