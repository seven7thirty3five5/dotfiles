# Locate Homebrew in the prefixes listed in .chezmoitemplates/brew-prefixes.
{{- $prefixes := splitList "\n" (includeTemplate "brew-prefixes" . | trim) }}
brew=
for prefix in {{ range $prefixes }}{{ . | shellQuote }} {{ end }}; do
  if [ -x "$prefix/bin/brew" ]; then
    brew=$prefix/bin/brew
    break
  fi
done
