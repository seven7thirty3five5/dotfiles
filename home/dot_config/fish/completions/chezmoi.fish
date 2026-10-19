# fish loads this the first time you complete a chezmoi command. chezmoi lives
# in ~/.local/bin rather than Homebrew, so it provides its own completions.
command -q chezmoi; and chezmoi completion fish | source
