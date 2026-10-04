# Portable XDG dotfiles

Chezmoi configurations for macOS and Linux.

## Prerequisites

- zsh is your shell.
- Install [Homebrew](https://docs.brew.sh/Installation) and follow its `shellenv`
  setup instructions. Homebrew recommends `.zprofile` on macOS and `.zshrc` on
  Linux for zsh; these dotfiles preserve that split. Make sure `brew` works in your
  current shell before continuing.
- Git and `chezmoi` are available (or bootstrap chezmoi below).
- LazyVim needs a C compiler; its plugins also use `curl`, `unzip`, and `gzip`.
  On macOS, use Apple's Command Line Tools. On Linux, install these utilities,
  GNU tar, and your distribution's development/build tools with the system package
  manager. The Brewfile supplies GNU tar on macOS for Mason.
- `~/.config/zsh/.zshrc.local` (optional) holds per-machine zsh settings such as
  aliases and functions. It is not tracked by chezmoi.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

## Initialize dotfiles

Initialize this repository without applying the dotfiles yet:

```sh
chezmoi init seven7thirty3five5
```

If `chezmoi` is not installed, bootstrap it and initialize instead:

```sh
sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin" init seven7thirty3five5
export PATH="$HOME/.local/bin:$PATH"
```

`init` asks for your Git name and email, and whether this machine should commit and
push dotfile changes (`autoCommit`/`autoPush`). Answer yes only on the machine you
publish from; other machines just pull.

Install the formulae, regenerate chezmoi's configuration so it detects `delta` and
`nvim`, then apply the dotfiles:

```sh
brew bundle --file="$(chezmoi source-path)/dot_config/homebrew/Brewfile" --no-upgrade
chezmoi init
chezmoi apply
```

Package installation is a manual step; `chezmoi apply` does not run it. The
[Brewfile](dot_config/homebrew/Brewfile) tracks formulae only and installs Mole only
on macOS. `--no-upgrade` skips explicit upgrades of existing packages; it does not
pin versions, and installing missing packages can still update their dependencies.
See [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile).

Open a new terminal after applying. If Homebrew is installed later, run
`chezmoi apply` again so the shell templates detect its location.

## Finish tool setup

### LazyVim

This repository already contains the LazyVim configuration and lazy.nvim
bootstrap. After applying the dotfiles, start Neovim:

```sh
nvim
```

On first launch, lazy.nvim downloads LazyVim and the configured plugins, using the
tracked `lazy-lock.json` for plugin revisions. Wait for installation to finish,
then run `:LazyHealth` and `:checkhealth mason` inside Neovim.

LazyVim automatically installs `tree-sitter-cli` through Mason when the executable
is missing, so it is omitted from the Brewfile. The C compiler and archive
utilities above support parser builds and Mason installations. See the
[LazyVim requirements](https://www.lazyvim.org/) and
[Mason requirements](https://github.com/mason-org/mason.nvim#requirements).

Language servers and formatters may need additional runtimes. Use your existing
pnpm-managed Node runtime or a per-project runtime when Node/npm is required;
Node and pnpm are not installed through this Brewfile.

### gh-dash

The Brewfile installs GitHub CLI (`gh`). On a new machine, authenticate with
`gh auth login` if needed, then install gh-dash as a GitHub CLI extension:

```sh
gh extension install dlvhdr/gh-dash
gh dash
```

This follows the [gh-dash installation instructions](https://www.gh-dash.dev/getting-started)
and uses the configuration managed at `~/.config/gh-dash/config.yml`. If the
extension is already installed, update it with `gh extension upgrade gh-dash`.

### Terminal, fonts, and Docker

- Install your terminal and fonts separately. The macOS Ghostty configuration uses
  JetBrains Mono. LazyVim and gh-dash display some icons with a Nerd Font v3 or
  newer; select that font in your terminal if you want those icons.
- `lazydocker` needs a working Docker installation and an accessible Docker daemon.
  Install and configure Docker for your OS separately.

## Install new dependencies

After pulling dotfile changes, review and install any missing formulae manually:

```sh
brew bundle check --file="$HOME/.config/homebrew/Brewfile" --no-upgrade --verbose
brew bundle --file="$HOME/.config/homebrew/Brewfile" --no-upgrade
```

## Sync dotfiles

To update your dotfiles such that they are synced with this repository, run:

```sh
chezmoi update
```

If chezmoi then warns that the config file template has changed, run `chezmoi init`
to regenerate this machine's config; it only asks questions it hasn't asked before.

## Validate shell configuration

GitHub Actions runs the shell checks on macOS and Linux for pushes and pull
requests. You can also run the same checks locally with Python 3.8+, `chezmoi`, and
`zsh` available:

```sh
python3 scripts/check-shell.py
```

The script renders the shell files and checks Zsh syntax, then tests login and
non-login startup in interactive and noninteractive modes. It verifies quiet
SSH-style startup, completion initialization, the editor fallback, PATH priority,
and the macOS `.zprofile` / Linux `.zshrc` split for Homebrew initialization.

Checks use temporary homes and a temporary source copy with a Homebrew stand-in;
optional shell tools are absent. System-wide profiles are skipped to focus the
checks on this repository. Standard Zsh functions are copied into private
temporary directories so shared runner permissions do not trigger completion
security prompts. They do not apply dotfiles, install packages,
download external themes, or use your local shell overrides. Application behavior
and integration with installed plugins still need checking on a configured machine.
