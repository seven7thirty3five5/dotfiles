# Find Homebrew: set $brew to the path of the brew command, or leave it empty
# if Homebrew isn't installed yet. (This snippet is shared by the scripts in
# home/.chezmoiscripts, which include it with a `template "find-brew.sh"` line.)
#
# chezmoi writes the folders to check, from .chezmoitemplates/brew-prefixes,
# into the `for` line. On a Mac, for example, the line becomes:
#   for prefix in /opt/homebrew; do
{{- $prefixes := splitList "\n" (includeTemplate "brew-prefixes" . | trim) }}
brew=
# macOS intentionally checks one supported prefix; Linux checks several.
# shellcheck disable=SC2043
for prefix in {{ range $index, $prefix := $prefixes }}{{ if $index }} {{ end }}{{ $prefix | shellQuote }}{{ end }}; do
  # -x: this file exists and is a program we can run.
  if [ -x "$prefix/bin/brew" ]; then
    # The including script uses brew; this fragment also gets linted by itself.
    # shellcheck disable=SC2034
    brew=$prefix/bin/brew
    break # use the first one found
  fi
done
