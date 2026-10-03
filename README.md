# Portable XDG dotfiles

Chezmoi configurations for macOS and Linux.

## Prerequisites

- `chezmoi` is installed; Git is available.
- zsh is your shell.
- Homebrew is the package manager for the configured development tools. Install it
  before applying: the configs look for it when chezmoi applies them, so if you add
  Homebrew later, run `chezmoi apply` again.
- `~/.config/zsh/.zshrc.local` (optional) holds per-machine zsh settings such as
  aliases and functions. It is not tracked by chezmoi.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

## Initialize dotfiles

To initialize and apply this dotfiles repository to your machine:

```sh
chezmoi init --apply seven7thirty3five5
```

or if you don't even have `chezmoi` installed, run:

```sh
sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply seven7thirty3five5
```

`init` asks for your Git name and email, and whether this machine should commit and
push dotfile changes (`autoCommit`/`autoPush`). Answer yes only on the machine you
publish from; other machines just pull.

## Sync dotfiles

To update your dotfiles such that they are synced with this repository, run:

```sh
chezmoi update
```

If chezmoi then warns that the config file template has changed, run `chezmoi init`
to regenerate this machine's config; it only asks questions it hasn't asked before.
