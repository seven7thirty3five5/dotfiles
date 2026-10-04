# Locate Homebrew in the prefixes listed in .chezmoitemplates/brew-prefixes.
brew=
for prefix in {{ range splitList "\n" (includeTemplate "brew-prefixes" . | trim) }}{{ . | shellQuote }} {{ end }}; do
  if [ -x "$prefix/bin/brew" ]; then
    brew=$prefix/bin/brew
    break
  fi
done
