# fish loads this the first time you complete a mise command. Asking the
# installed mise for its completions keeps them in step with its version.
command -q mise; and mise completion fish | source
