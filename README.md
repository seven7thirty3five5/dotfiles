# Portable XDG dotfiles

Personal dotfiles for macOS (Apple silicon) and Linux (x86_64 and ARM64).

## Requirements

- Your own user account (setup refuses to run as root or with sudo), with `curl`.
- `~/.local/bin` on your login shell's PATH. These dotfiles never touch your
  shell's startup files, such as `~/.zshrc` and `~/.bashrc`. Instead, setup
  links Homebrew's `herdr` into `~/.local/bin`, next to chezmoi and mise, and
  your shell finds it there. Debian and Ubuntu add the folder in `~/.profile`
  once it exists, so log in again after setup; Fedora and RHEL add it in
  `~/.bashrc`. Elsewhere, including macOS, add this line to your shell's
  startup file (`~/.zprofile` for macOS's zsh):

  ```sh
  export PATH="$HOME/.local/bin:$PATH"
  ```

## Setup

Run:

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

Setup replaces any existing files it manages, such as `~/.editorconfig` and the
configs in `~/.config`. To download the repository and preview changes first:

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

Claude Code and Codex settings stay local: chezmoi ignores `~/.claude` and
`~/.codex`. Configure and sign in to each agent separately. On a new machine,
run `update` to install herdr's hooks for both, then review and trust the Herdr
session hook through Codex's `/hooks` so Herdr can identify the Codex session
in each pane.

herdr installs and owns its hooks for Claude Code and Codex
(`herdr integration install`), so they aren't tracked; `update` installs them
at herdr's current version.

## Maintain

Run these inside fish:

```fish
update          # Upgrade chezmoi, dotfiles, Homebrew packages, mise and its tools,
                # global agent skills, gh extensions and herdr integrations.
doctor          # Check Homebrew, chezmoi, mise and authorization.
chezmoi update  # Pull and apply just the dotfiles, installing newly configured dependencies.
```

`update` accepts confirmations automatically, replaces local edits to managed
files, and stops at the first failure. Save shared changes in the repository and
machine-specific changes in `config-local.fish` before running it.

`doctor` continues after failed checks and returns a failure if any required
check fails. Its Authorization section checks Claude Code, Codex and GitHub.
It also reports Docker Hub sign-in status when Docker Desktop's auth command
is available; this optional sign-in doesn't affect the result.

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

Global agent skills are listed in the
[install-skills script](home/.chezmoiscripts/run_onchange_after_60-install-skills.sh.tmpl):
herdr's skill and every skill in Matt Pocock's repository. The
[skills tool](https://skills.sh) installs each one in `~/.agents/skills`, for
Codex and other agents, and links it into `~/.claude/skills` for Claude Code.
To add one, add a `skills_add` line there and run `chezmoi apply`. The skills
tool owns the installed files, so they aren't tracked here.

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
- **fish inside herdr** holds the working environment. Your login shell stays as
  you set it up: installation never changes it, `$SHELL` or its startup files,
  and it only needs `~/.local/bin` on PATH to start herdr. To opt out of this
  setup, use the login shell without starting herdr. Fish supplies mise's shims
  to scripts and popups as well as interactive panes.
- **XDG directories** hold configuration, data, state and caches wherever supported.
  Catppuccin Mocha provides the shared theme.
- **Machine-specific settings** go in the untracked
  `~/.config/fish/config-local.fish`, loaded last in every fish shell.

## To do

These dotfiles don't set up the following yet:

- Docker on Linux, which `lazydocker` and `act` need. macOS installs Docker Desktop.
