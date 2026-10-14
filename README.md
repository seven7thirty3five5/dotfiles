# Portable XDG dotfiles

Personal dotfiles for macOS (Apple silicon) and Linux (x86_64 and ARM64).

## Setup

Run as your own user, with `curl` available:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
```

Setup asks for your Git name and email, whether this machine should automatically
commit and push dotfile changes, and whether it may use sudo. Enable publishing
only on the machine you publish from.

The installer sets up chezmoi, Homebrew and the Brewfile packages, gh-dash, mise and
its configured runtimes. It applies the dotfiles and is safe to rerun after fixing
any errors or completing the manual steps it lists.

Without sudo, setup can install Homebrew in your home folder on Linux; system
dependencies still need an administrator. On macOS without sudo, Homebrew must
already be installed in `/opt/homebrew`.

Setup replaces existing managed files, including `~/.zprofile` on macOS and
`~/.bashrc` on Linux. To download the repository and preview changes first:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --use-builtin-git=true seven7thirty3five5
"$HOME/.local/bin/chezmoi" diff --exclude=scripts
```

Keep any machine-specific shell settings in `~/.config/fish/config-local.fish`
using fish syntax, then run the setup command above to apply.

## Use

Open a new terminal and run `herdr`. Its panes run fish with the configured tools,
runtimes and shortcuts.

| Command or shortcut | Purpose |
| --- | --- |
| `micro` | Open the default editor. |
| `ff` | Open Yazi, then change to its directory when you exit. |
| Ctrl-R | Search shell history with atuin. |
| Ctrl-Space, then Alt-G | Open lazygit in a herdr popup. |
| Ctrl-Space, then Alt-H | Open gh-dash in a herdr popup. |

Run `gh auth login` before using `gh dash`. On macOS, open Docker Desktop and
finish its setup before using `lazydocker` or `act`; Linux needs Docker installed
separately.

Codex uses **Approve for me**, `max` reasoning, Fast service, and Catppuccin Mocha.
Its footer shows the model and reasoning, Fast mode, directory, five-hour and
weekly allowances, context usage, and context capacity. Other preferences use
Codex's defaults. Sign in to Codex separately; on a new machine, review and trust
the Herdr session hook through `/hooks` so Herdr can identify the Codex session
in each pane.

Edit the [Codex template](home/private_dot_codex/private_config.toml.tmpl) for
shared preferences. It preserves each machine's existing MCP connections,
app/plugin settings, project and hook trust, and client bookkeeping during apply.
Credentials, conversations, and downloaded runtime files aren't tracked. To apply
just Codex:

```sh
chezmoi apply --exclude=scripts ~/.codex/config.toml ~/.codex/hooks.json ~/.codex/herdr-agent-state.sh
```

## Maintain

Run these inside fish:

```fish
update          # Upgrade Homebrew packages, gh extensions, chezmoi, dotfiles, mise and its tools.
doctor          # Run brew doctor, chezmoi doctor and mise doctor.
chezmoi update  # Pull and apply just the dotfiles, installing newly configured dependencies.
```

`update` accepts confirmations automatically, replaces local edits to managed
files, and stops at the first failure. Save shared changes in the repository and
machine-specific changes in `config-local.fish` before running it.

Edit a managed configuration and apply it:

```sh
chezmoi edit ~/.config/fish/config.fish
chezmoi diff
chezmoi apply
```

Use `chezmoi add PATH` to track another file. With publishing enabled, chezmoi
edits and additions automatically commit and push. For direct repository edits,
use `git add`, `git commit` and `git push`.

For package or global runtime changes, run `chezmoi cd` and edit the
[Brewfile](home/dot_config/homebrew/Brewfile.tmpl) or
[mise config](home/dot_config/mise/config.toml), then run `chezmoi apply`.
Keep project-specific runtime settings in each project.

Change setup answers under `[data]` in `~/.config/chezmoi/chezmoi.toml`.
Run `chezmoi init` if chezmoi warns that its config template has changed.
To refresh downloaded themes immediately, run `chezmoi apply --refresh-externals`.

## Design

- **chezmoi** owns configuration files and setup scripts. `home/` is the source
  state; files outside it are not deployed.
- **Homebrew** owns shell tools and macOS apps.
- **mise** owns language runtimes and package managers: Node LTS, plus Python, uv
  and pnpm at `latest`. Projects can override versions; mise reads `.nvmrc` and
  `.node-version`, while uv owns `.python-version`.
- **fish inside herdr** holds the working environment. Login shells stay zsh on
  macOS and bash on Linux, with minimal Homebrew setup. Installation does not
  change the login shell or `$SHELL`. Fish supplies mise's shims to scripts and
  popups as well as interactive panes.
- **XDG directories** hold configuration, data, state and caches wherever supported.
  Catppuccin Mocha provides the shared theme.
- **Machine-specific settings** go in the untracked
  `~/.config/fish/config-local.fish`, loaded last in every fish shell.

## To do

These dotfiles don't set up the following yet:

- Docker on Linux, which `lazydocker` and `act` need. macOS installs Docker Desktop.
