# Portable XDG dotfiles

Chezmoi configurations for macOS and Linux.

## Prerequisites

- Homebrew is the package manager for the configured development tools.
- zsh is your shell; Git is available.
- chezmoi is installed.
- `~/.aliases` and `~/.functions` exist for per-machine customizations. They are
  not tracked by chezmoi.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

## Apply the dotfiles

Use this public repository directly, or fork it and substitute your fork's URL:

```sh
chezmoi init --apply https://github.com/seven7thirty3five5/dotfiles.git
```

Reading this public repository requires no GitHub login. Enter your Git author
name and email when prompted, using your work email on work machines. These values
stay in your local chezmoi config. Start a new zsh login shell afterward.

## Pull updates

If you use a fork, [sync it with this repository](https://docs.github.com/en/pull-requests/how-tos/work-with-forks/syncing-a-fork#syncing-a-fork-branch-from-the-web-ui)
first. Pull and apply the latest commits from your configured repository with:

```sh
chezmoi update
```
