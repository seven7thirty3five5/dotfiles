# Portable XDG dotfiles

Chezmoi configurations for macOS (Apple silicon) and Linux (x86_64 and ARM64).

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

[`install.sh`](install.sh) first checks that it can run: it stops if you run it as root,
on an Intel Mac or another unsupported system, or if `~/.local/share/chezmoi` already
holds other dotfiles. It installs chezmoi in `~/.local/bin`, where it stays (update it
with `chezmoi upgrade`), and runs `chezmoi init --apply`. That writes the dotfiles, then
runs the scripts in [`home/.chezmoiscripts`](home/.chezmoiscripts) in this order:

1. **System packages**, on Linux with sudo only: what Homebrew needs (build tools,
   `curl`, `file`, `git`), plus `unzip` and zsh, with `apt-get`, `dnf` or `pacman`.
2. **Homebrew**, if it is missing (an existing installation is reused without sudo):
   - macOS (Apple silicon): `/opt/homebrew` is the only supported prefix, and
     installing it needs sudo. If you answered no, this step fails and the list at
     the end says to ask an administrator to install Homebrew there. Homebrew
     installs Apple's Command Line Tools when needed.
   - Linux, with sudo: `/home/linuxbrew/.linuxbrew`.
   - Linux, without sudo: `~/.linuxbrew`, or `~/.brew` when that path would be longer
     than the default. Homebrew uses its prebuilt bottles in a custom prefix only if it
     is no longer than the default ([support tiers](https://docs.brew.sh/Support-Tiers)).
     A C compiler, `file`, `git` and `unzip` must then come from your administrator.
3. **The [Brewfile](home/dot_config/homebrew/Brewfile.tmpl)**, with `brew bundle --no-upgrade`.
   Mole, GNU tar and the Ghostty cask are macOS-only; the Brewfile is a template that
   leaves them out on Linux. The cask adopts an existing Ghostty app.
4. **[gh-dash](https://www.gh-dash.dev/)**, the GitHub CLI extension.
5. **[mise](https://mise.jdx.dev/)**, from its official installer into `~/.local/bin`,
   then Node.js (LTS), Python, uv and pnpm from
   [`home/dot_config/mise/config.toml`](home/dot_config/mise/config.toml). This works
   without Homebrew or sudo. Existing versions are reused; a config change makes
   chezmoi run `mise install` again without rewriting that config.
6. **zsh as the login shell**, only if you answered yes to sudo: the system's own zsh,
   `/bin/zsh` on macOS (already the default there) or `/usr/bin/zsh` on Linux, set
   with `chsh` (sudo asks for your password). If that isn't possible, setup carries on.

Because the dotfiles are written first, a machine where a script fails, for example
because Homebrew can't be installed there, still gets them. chezmoi tries a failed
script again on the next `chezmoi apply` or `chezmoi update`, and `install.sh` runs
chezmoi with `--keep-going`, so one failed script doesn't stop the others.

After the setup scripts, `install.sh` runs `chezmoi init` and `chezmoi apply` once
more, so that chezmoi's own config picks up `delta` and `nvim`, the zsh and git
configs pick up Homebrew, and mise's tab completion is generated. This second pass
also runs without Homebrew, so mise's completion still arrives. Finally it lists
anything left to do by hand, such as asking an administrator (IT) to install zsh
and make it your login shell, and it ends with an error if a step failed. Re-running
it is safe, and extra arguments are passed to `chezmoi init`. To change an answer
later, edit it under `[data]` in `~/.config/chezmoi/chezmoi.toml`.

### On a machine that already has dotfiles

The install replaces every existing file that these dotfiles manage, such as
`~/.config/git/config` or `~/.config/nvim/init.lua`, and leaves other files alone.
zsh stops reading the startup files in your home folder, such as `~/.zshrc`, because
these dotfiles move them to `~/.config/zsh`. To see what would change first, download
chezmoi and the repository without applying anything, then compare:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --use-builtin-git=true seven7thirty3five5
"$HOME/.local/bin/chezmoi" diff --exclude=scripts
```

The first command also asks the setup questions. Copy anything you want to keep, such
as machine-specific aliases, into `~/.config/zsh/.zshrc.local`, then run the
one-command install above; it reuses the downloaded repository and your answers.

### After setup

- Open a new terminal.
- Start Neovim (`nvim`): the first time, LazyVim installs its plugins, which takes a
  minute and needs internet access. Then `:LazyHealth` and `:checkhealth mason`
  report anything still missing. mise puts Node and its bundled npm on PATH, so
  LazyVim extras whose language servers are npm packages (such as `lang.json` or
  `lang.typescript`) can now be installed. No additional extras are enabled here.
- Run `gh auth login` before using `gh dash`; installing it needed no login.
- Ghostty bundles JetBrains Mono and the Nerd Font symbols. Over SSH, LazyVim, lazygit,
  eza and gh-dash icons need a Nerd Font (v3 or newer) in the connecting terminal.
- `lazydocker` and `act` need a working Docker installation, which you set up separately.
- `~/.config/zsh/.zshrc.local` (optional) holds per-machine zsh settings such as
  aliases and functions. It is not tracked by chezmoi. Lines that installers (Docker
  Desktop, conda, nvm and so on) offer to add to `~/.zshrc` belong there too.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

## Sync dotfiles

```sh
chezmoi update
```

This pulls the repository and applies it. When the Brewfile or mise config changes,
the scripts also install the new packages or runtimes. If chezmoi warns that the
config file template has changed, run `chezmoi init` to regenerate this machine's
config; it only asks questions it hasn't asked before.

To update everything at once, run `update`, an alias in `.zshrc`:

```sh
brew update && brew upgrade && chezmoi upgrade && mise self-update --yes && chezmoi update && mise upgrade && gh extension upgrade --all
```

`mise self-update` comes before `chezmoi update`, so the same run regenerates mise's
tab completion with the updated program. `mise upgrade` upgrades the configured
tools and automatically prunes replaced versions after its grace period. The `&&`
between commands stops the update at the first failure.

Run `doctor` to check all three managers:

```sh
brew doctor; chezmoi doctor; mise doctor
```

The semicolons let every check run: Homebrew reports even warnings with an error
exit status, which would stop a chain joined with `&&`. Both aliases are defined
only when their required commands are installed.

Neovim's plugins are updated inside Neovim, when you choose, with
`:Lazy update`; LazyVim's statusline shows how many updates are available, and each
machine keeps its own record of plugin versions in `~/.config/nvim/lazy-lock.json`.
Mason's tools (language servers and formatters) are updated there too: open `:Mason`
and press `U`.

## Use these dotfiles yourself

Fork this repository instead of installing it directly: `install.sh` and
`chezmoi update` install whatever is on the repository's `main` branch. In your fork,
change `repo` at the top of `install.sh` and the username in the commands above to
yours, and change `repoPaths` in [`gh-dash/config.yml`](home/dot_config/gh-dash/config.yml)
to your GitHub username.

## Repository layout

- `home/` is the chezmoi source state, as named in `.chezmoiroot`. Everything outside it
  (this README, `LICENSE`, `install.sh`, `scripts/`, `.github/`) is never deployed.
- `.chezmoiversion` sets the oldest chezmoi that can read the source state.
- `~/.config/gh/config.yml` is a symlink to `.config.yml` in `home/dot_config/gh/`,
  because gh rewrites it. Its changes appear in this repository as ordinary git changes.

### Language runtimes

chezmoi manages files and setup scripts, Homebrew installs shell tools and apps,
and mise manages language runtimes and their package managers. Node, Python, uv
and pnpm are kept out of the Brewfile so each has one owner.

The global fallback versions in `~/.config/mise/config.toml` are Node `lts` (npm
comes with Node), and Python, uv and pnpm `latest`. mise reads a project's `.nvmrc`
or `.node-version` to choose Node there. uv owns `.python-version` and manages each
project's Python; mise supplies the global Python fallback.

Permanent global changes go in
[`home/dot_config/mise/config.toml`](home/dot_config/mise/config.toml), then are
applied with chezmoi. `mise use -g` changes only this machine's copy, which chezmoi
would overwrite on the next apply. Project-specific mise configs stay with their
projects.

zsh login shells load mise's shims in `.zprofile`; interactive shells load full
activation in `.zshrc` to switch versions when you change folders. mise's settings,
data, state and cache use the XDG folders; `mise doctor` shows their paths.

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
- `.chezmoiignore` lists files chezmoi leaves alone: some only on some machines, and
  some, such as Neovim's `lazy-lock.json`, everywhere.
- `.chezmoiexternal.toml` lists files that chezmoi downloads instead of keeping them
  here: the Catppuccin themes.
- `.chezmoitemplates/` holds template pieces that several files share, such as how
  to find Homebrew.
- `.chezmoiscripts/` holds the setup scripts. A `run_once_` script runs once per
  machine (and again if it changes), a `run_onchange_` script again whenever its
  contents change, and `before_` or `after_` says whether it runs before or after
  chezmoi writes the files. The numbers set the order. A script that fails runs
  again on the next apply.

Most files explain themselves in comments. A few can't hold any: `.chezmoiroot` (just
the folder name, `home`), `.chezmoiversion` (just a version number), `LICENSE` (the
standard MIT license text), `empty_dot_hushlogin`, and `lazyvim.json`, the LazyVim
extras turned on with `:LazyExtras`, which LazyVim writes itself.

## Validate

GitHub Actions runs three workflows on pushes and pull requests:

- **Shell checks** run ShellCheck and shfmt on plain shell scripts and on chezmoi
  templates rendered for macOS and Linux (x86_64 and ARM64) with both answers to the
  sudo question, and actionlint on all workflows, then run `scripts/check-shell.py`
  on macOS and Linux.
- **Bootstrap** runs `install.sh` against the pushed commit on GitHub's macOS runner
  and its x86_64 and ARM64 Ubuntu runners, and in fresh Ubuntu containers on both
  architectures, as a user with sudo and as one without, who answers no to the sudo
  question (Homebrew then goes into the home folder). `scripts/check-install.sh` then
  checks the result: the tools on PATH, `chezmoi verify`, that setup left the
  repository unchanged, the Homebrew prefix, the gh config symlink, gh-dash and,
  where setup may use sudo, the login shell.
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

## To do

These dotfiles don't set up the following yet:

- Docker, which `lazydocker` and `act` need.

## License

[MIT](LICENSE). The Neovim config in `home/dot_config/nvim` started from
[LazyVim's starter](https://github.com/LazyVim/starter) (Apache-2.0), and the atuin,
btop and gh-dash configs start from the default settings those tools generate; those
parts remain under their projects' licenses.
