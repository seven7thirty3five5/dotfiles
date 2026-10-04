# Portable XDG dotfiles

Chezmoi configurations for macOS (Apple silicon) and Linux.

## Set up a new machine

Run one command. It asks for your Git name and email, whether this machine should
commit and push dotfile changes (answer yes only on the machine you publish from), and
whether it may use sudo. Answer no to the sudo question on a machine where you have no
administrator rights, such as a locked-down work computer: setup then never runs sudo,
so it never asks for a sudo password, and at the end it lists what you still need an
administrator for.

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
```

[`install.sh`](install.sh) runs `chezmoi init --apply`, and the scripts in
[`home/.chezmoiscripts`](home/.chezmoiscripts) set the machine up in this order:

1. **Homebrew**, if it is missing (an existing installation is reused without sudo):
   - macOS (Apple silicon): `/opt/homebrew` is the only supported prefix, and
     installing it needs sudo. If you answered no, setup stops and says to ask an
     administrator to install Homebrew there. Homebrew installs Apple's Command Line
     Tools when needed. Intel Macs are not supported by these dotfiles.
   - Linux, with sudo: `/home/linuxbrew/.linuxbrew`. Setup first installs the build
     tools Homebrew requires, plus unzip, with `apt-get`, `dnf` or `pacman`.
   - Linux, without sudo: `~/.linuxbrew`, or `~/.brew` when that path would be longer
     than the default. Homebrew uses its prebuilt bottles in a custom prefix only if it
     is no longer than the default ([support tiers](https://docs.brew.sh/Support-Tiers)).
     A C compiler, `file` and `unzip` must then come from your administrator.
2. **The [Brewfile](home/dot_config/homebrew/Brewfile.tmpl)**, with `brew bundle --no-upgrade`.
   It includes zsh itself, so macOS and Linux run the same version. Mole, GNU tar and
   the Ghostty cask are macOS-only; the Brewfile is a template that leaves them out on
   Linux. The cask adopts an existing Ghostty app.
3. **The dotfiles** themselves.
4. **[gh-dash](https://www.gh-dash.dev/)**, the GitHub CLI extension.
5. **LazyVim's plugins**, headless, at the versions in `lazy-lock.json`.
6. **Homebrew's zsh as the login shell**, only if you answered yes to sudo: setup
   adds it to `/etc/shells` and switches to it with `chsh` (sudo asks for your
   password). If that isn't possible, setup carries on.

`install.sh` then initializes Homebrew in its own shell and runs `chezmoi init` once
more so chezmoi's own config picks up `delta` and `nvim`. Finally it lists anything
left to do by hand, such as asking an administrator (IT) to change your login shell
or to install a C compiler, `file` or `unzip`. Re-running it is safe, and extra
arguments are passed to `chezmoi init`. To change an answer later, edit it under
`[data]` in `~/.config/chezmoi/chezmoi.toml`.

### On a machine that already has dotfiles

The install replaces any existing file that these dotfiles manage, and deletes the old
files listed in [`home/.chezmoiremove`](home/.chezmoiremove), such as `~/.zshrc`,
without asking and without a backup. To see what would change first, download chezmoi
and the repository without applying anything, then compare:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init seven7thirty3five5
"$HOME/.local/bin/chezmoi" diff --exclude=scripts
```

The first command also asks the setup questions. Copy anything you want to keep, such
as machine-specific aliases, into `~/.config/zsh/.zshrc.local`, then run the
one-command install above; it reuses the downloaded repository and your answers.

### After setup

- Open a new terminal.
- Run `gh auth login` before using `gh dash`; installing it needed no login.
- In Neovim, `:LazyHealth` and `:checkhealth mason` report anything still missing.
  Node isn't installed or put on PATH, so LazyVim extras whose language servers are
  npm packages (such as `lang.json` or `lang.typescript`) can't install until it is.
- Ghostty bundles JetBrains Mono and the Nerd Font symbols. Over SSH, LazyVim, lazygit,
  eza and gh-dash icons need a Nerd Font (v3 or newer) in the connecting terminal.
- `lazydocker` and `act` need a working Docker installation, which you set up separately.
- `~/.config/zsh/.zshrc.local` (optional) holds per-machine zsh settings such as
  aliases and functions. It is not tracked by chezmoi.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

## Sync dotfiles

```sh
chezmoi update
```

This pulls the repository and applies it. When the Brewfile, `lazy-lock.json` or the
LazyVim extras change, the scripts also install the new packages and plugin versions.
If chezmoi warns that the config file template has changed, run `chezmoi init` to
regenerate this machine's config; it only asks questions it hasn't asked before.

## Repository layout

- `home/` is the chezmoi source state, as named in `.chezmoiroot`. Everything outside it
  (this README, `install.sh`, `scripts/`, `.github/`) is never deployed.
- `.chezmoiversion` sets the oldest chezmoi that can read the source state.
- `~/.config/nvim/lazy-lock.json` and `~/.config/gh/config.yml` are symlinks to
  `.lazy-lock.json` and `.config.yml` in `home/`, because lazy.nvim and gh rewrite
  them. Their changes appear in this repository as ordinary git changes.

### Shell and workflow tools

The Brewfile installs [ShellCheck](https://github.com/koalaman/shellcheck),
[shfmt](https://github.com/mvdan/sh), [act](https://github.com/nektos/act) and
[actionlint](https://github.com/rhysd/actionlint) on macOS and Linux.

- ShellCheck reads `~/.config/shellcheckrc` (or `$XDG_CONFIG_HOME/shellcheckrc`). It
  checks sourced files and resolves them relative to each script. Project configs
  take precedence; the global config keeps the standard checks and shell detection.
- shfmt reads `~/.editorconfig`; it has no separate global config or shell init.
  Shell files use two spaces, indented case arms and continued operators at the
  start of the next line. Project EditorConfig settings take precedence.
  The lint runner copies `home/dot_editorconfig` into its temporary home, so CI
  uses the same settings without first applying the dotfiles.
- act reads `$XDG_CONFIG_HOME/act/actrc`. It uses the upstream Medium Ubuntu images
  and, on Apple silicon, amd64 containers. Its caches follow `$XDG_CACHE_HOME`.
  Project `.actrc` files and CLI arguments can override these defaults. Homebrew
  installs its Zsh completion, which the existing `fpath` and `compinit` setup load.
- actionlint checks every workflow when run from a repository. It automatically
  uses ShellCheck for shell steps. Its optional config belongs to the project at
  `.github/actionlint.yaml`; the standard defaults fit this repo, so there is no
  global config or init command.

From the repository root:

```sh
shellcheck install.sh scripts/check-install.sh
shfmt -w install.sh scripts/check-install.sh
actionlint
act --list
act -W .github/workflows/shell-checks.yml -j shell --matrix os:ubuntu-latest
```

`act --list` only lists jobs and needs no running Docker daemon. Running a job
downloads the runner image when needed and starts Docker containers. For this repo,
select the Linux shell job as above; the Bootstrap workflow installs packages and
changes the login shell, and macOS jobs need a real macOS runner. Keep GitHub
tokens out of tracked configs; pass a required token interactively with
`act -s GITHUB_TOKEN`.

### How chezmoi reads `home/`

Each file in `home/` becomes a file in your home folder, and its name says how:

| Name in `home/`                | What chezmoi does                                                   |
| ------------------------------ | ------------------------------------------------------------------- |
| `dot_zshenv`                   | Writes `~/.zshenv`: `dot_` stands for the leading dot.              |
| `dot_config/git/config.tmpl`   | Writes `~/.config/git/config`, filled in as a template (`.tmpl`).   |
| `empty_dot_hushlogin`          | Writes `~/.hushlogin`, keeping it although it's empty (`empty_`).   |
| `symlink_config.yml.tmpl`      | Makes `config.yml` a symlink; the file holds the path it points to. |
| `.config.yml`, or any name starting with a dot | Nothing: chezmoi skips it.                          |

A template is a file with parts between double braces (`{{ ... }}`) that chezmoi fills
in for each machine: for example only its macOS or its Linux part, or the name and
email you gave during setup.

The names starting with `.chezmoi` control chezmoi itself:

- `.chezmoi.toml.tmpl` asks the setup questions and writes each machine's chezmoi
  settings.
- `.chezmoiignore` lists files not to install on some machines, and `.chezmoiremove`
  lists old files to delete.
- `.chezmoiexternal.toml` lists files that chezmoi downloads instead of keeping them
  here: the Catppuccin themes.
- `.chezmoitemplates/` holds template pieces that several files share, such as how
  to find Homebrew.
- `.chezmoiscripts/` holds the setup scripts. A `run_once_` script runs once per
  machine (and again if it changes), a `run_onchange_` script again whenever its
  contents change, and `before_` or `after_` says whether it runs before or after
  chezmoi writes the files. The numbers set the order.

Most files explain themselves in comments. A few can't hold any: `.chezmoiroot` (just
the folder name, `home`), `.chezmoiversion` (just a version number),
`empty_dot_hushlogin`, and two JSON files that Neovim's plugins write themselves:
`lazyvim.json`, the LazyVim extras turned on with `:LazyExtras`, and `.lazy-lock.json`,
in which lazy.nvim records the exact version of each plugin.

## Validate

GitHub Actions runs three workflows on pushes and pull requests:

- **Shell checks** run ShellCheck and shfmt on plain shell scripts and on chezmoi
  templates rendered for macOS and Linux with both answers to the sudo question, and
  actionlint on all workflows, then run `scripts/check-shell.py` on macOS and Linux.
- **Bootstrap** runs `install.sh` against the pushed commit on GitHub's macOS and
  Ubuntu runners, and in fresh Ubuntu containers as a user with sudo and as one
  without, who answers no to the sudo question (Homebrew then goes into the home
  folder). `scripts/check-install.sh` then checks the result: the tools on PATH,
  `chezmoi verify`, the Homebrew prefix, the symlinks, gh-dash, LazyVim's plugins
  and, where setup may use sudo, the login shell.
- **Secret scan** runs gitleaks over the whole history, which also covers edits made
  without `chezmoi add` and its secret check.

You can also run the checks locally with Python 3.8+, `chezmoi`, `zsh`, `shellcheck`,
`shfmt` and `actionlint` available:

```sh
python3 scripts/check-lint.py
python3 scripts/check-shell.py
```

`check-shell.py` renders the shell files and checks Zsh syntax, then tests login and
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
