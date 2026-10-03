# Portable XDG dotfiles

Chezmoi configurations for macOS and Linux.

## Prerequisites

- `chezmoi` is installed; Git is available.
- zsh is your shell.
- Homebrew is the package manager for the configured development tools.
- `~/.aliases` and `~/.functions` exist for per-machine customizations. They are
  not tracked by chezmoi.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

## Initialize dotfiles

To initialize and apply this dotfiles repository to your machine:

```sh
chezmoi init --apply seven7thirty3five5
```

or if you don't even have `chezmoi` installed, run:

```sh
sh -c "$(curl -fsSL get.chezmoi.io)" -- init --apply seven7thirty3five5
```

## Sync dotfiles

To update your dotfiles such that they are synced with this repository, run:

```sh
chezmoi update
```
