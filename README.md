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
   `curl`, `file`, `git`), with `apt-get`, `dnf` or `pacman`.
2. **Homebrew**, if it is missing (an existing installation is reused without sudo):
   - macOS (Apple silicon): `/opt/homebrew` is the only supported prefix, and
     installing it needs sudo. If you answered no, this step fails and the list at
     the end says to ask an administrator to install Homebrew there. Homebrew
     installs Apple's Command Line Tools when needed.
   - Linux, with sudo: `/home/linuxbrew/.linuxbrew`.
   - Linux, without sudo: `~/.linuxbrew`, or `~/.brew` when that path would be longer
     than the default. Homebrew uses its prebuilt bottles in a custom prefix only if it
     is no longer than the default ([support tiers](https://docs.brew.sh/Support-Tiers)).
     A C compiler, `file` and `git` must then come from your administrator.
3. **The [Brewfile](home/dot_config/homebrew/Brewfile.tmpl)**, with `brew bundle --no-upgrade`,
   including fish and herdr.
   Mole and the app casks are macOS-only; the Brewfile is a template
   that leaves them out on Linux. The apps are Ghostty, CodexBar, Docker Desktop,
   Stats, Rectangle, BetterDisplay and Logi Options+.
   jq comes from Homebrew on both systems, like git, so both use Homebrew's
   current release rather than an OS-provided version. See below for adopting
   existing macOS apps.
4. **[gh-dash](https://www.gh-dash.dev/)**, the GitHub CLI extension.
5. **[mise](https://mise.jdx.dev/)**, from its official installer into `~/.local/bin`,
   then Node.js (LTS), Python, uv and pnpm from
   [`home/dot_config/mise/config.toml`](home/dot_config/mise/config.toml). This works
   without Homebrew or sudo. Existing versions are reused; a config change makes
   chezmoi run `mise install` again without rewriting that config.
6. **The login shell**, on Linux with sudo only: if an earlier version of these
   dotfiles made zsh your login shell, it switches back to the system's bash with
   `chsh` (sudo asks for your password). Otherwise the login shell is left alone:
   `/bin/zsh` on macOS and bash on Linux, the systems' defaults (see
   [The shell](#the-shell-fish-inside-herdr)). If that isn't possible, setup carries on.

Because the dotfiles are written first, a machine where a script fails, for example
because Homebrew can't be installed there, still gets them. chezmoi tries a failed
script again on the next `chezmoi apply` or `chezmoi update`, and `install.sh` runs
chezmoi with `--keep-going`, so one failed script doesn't stop the others.

After the setup scripts, `install.sh` runs `chezmoi init` and `chezmoi apply` once
more, so that chezmoi's own config picks up `delta` and fish, the shell, git and
herdr configs pick up Homebrew and fish, and mise's tab completion is generated.
This second pass also runs without Homebrew, so mise's completion still arrives.
Finally it lists anything left to do by hand, such as asking an administrator (IT)
to make bash your login shell, and it ends with an error if a step failed. Re-running
it is safe, and extra arguments are passed to `chezmoi init`. To change an answer
later, edit it under `[data]` in `~/.config/chezmoi/chezmoi.toml`.

### On a machine that already has dotfiles

The install replaces every existing file that these dotfiles manage, such as
`~/.config/git/config` or `~/.config/fresh/config.json`, and leaves other files alone.
That includes the login shell's startup file: `~/.zprofile` on macOS and `~/.bashrc`
on Linux, which afterwards only put Homebrew on PATH. To see what would change first,
download chezmoi and the repository without applying anything, then compare:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --use-builtin-git=true seven7thirty3five5
"$HOME/.local/bin/chezmoi" diff --exclude=scripts
```

The first command also asks the setup questions. Copy anything you want to keep, such
as machine-specific aliases, into `~/.config/fish/config-local.fish` (in fish's
syntax), then run the one-command install above; it reuses the downloaded repository
and your answers.

### After setup

- Open a new terminal and start `herdr`; its panes run fish.
- Micro (`micro`, or `ww`) is the default editor, and `$EDITOR` and `$VISUAL` for
  programs such as git. Its [official Catppuccin Mocha theme](https://github.com/catppuccin/micro)
  is downloaded with the other themes; `~/.config/micro/settings.json` selects it
  and enables truecolor. Fresh is also installed and available with `fresh`.
- `ff` opens Yazi and changes the shell to the directory selected when you exit.
- Run `gh auth login` before using `gh dash`; installing it needed no login.
- Ghostty bundles JetBrains Mono and the Nerd Font symbols. Over SSH, yazi, lazygit,
  eza and gh-dash icons need a Nerd Font (v3 or newer) in the connecting terminal.
- On macOS, open Docker Desktop once and finish its setup before using `lazydocker`
  or `act`. On Linux, set up Docker separately.
- `~/.config/fish/config-local.fish` (optional) holds per-machine fish settings such
  as abbreviations and functions. It is not tracked by chezmoi. Lines that installers
  (Docker Desktop, conda, nvm and so on) offer to add to fish's `config.fish` belong
  there too.

**Rule:** Follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
wherever supported, using its standard paths.

### Existing macOS apps

You do not need to uninstall these apps before adding them to the Brewfile.
`brew bundle` automatically uses Homebrew's [app adoption](https://docs.brew.sh/Tips-and-Tricks#adopt-a-manually-installed-app-as-a-cask),
so existing app bundles stay in place and their settings remain intact. The setup
also uses `--no-upgrade`, leaving apps that Homebrew already manages as they are.

Logi Options+ is an exception to app adoption: its [cask](https://formulae.brew.sh/cask/logi-options%2B)
runs Logitech's installer with administrator access and requires a reboot.
An existing installation does not need to be removed first, but the vendor
installer will run the first time Homebrew registers this cask.

Docker Desktop also installs CLI symlinks. Homebrew may report a conflict if
existing links point somewhere other than `/Applications/Docker.app`, such as
macOS's temporary `AppTranslocation` location. Before the first apply, make sure
those links point into `/Applications/Docker.app/Contents/Resources`, rather than
uninstalling Docker. Docker's [Advanced settings](https://docs.docker.com/desktop/settings-and-maintenance/settings/#advanced-mac-only)
let you reconfigure CLI installation paths. This only concerns the CLI links;
leave Docker's settings, images and containers in place.

## The shell: fish inside herdr

You work inside [herdr](https://herdr.dev), and every herdr pane runs
[fish](https://fishshell.com). The login shells stay the systems' own and only start
herdr.

### How it starts

- **macOS**: Ghostty opens a login `/bin/zsh`, macOS's default. zsh reads
  [`~/.zprofile`](home/dot_zprofile.tmpl), which holds only Homebrew's documented
  setup line, so `herdr` is on PATH. Type `herdr`. (`zsh -c` doesn't read that file.)
- **Linux**: an SSH login starts bash. The system's own login file (`~/.profile` on
  Debian and Ubuntu, `~/.bash_profile` on Fedora, RHEL and Arch, `/etc/profile` on
  openSUSE) reads [`~/.bashrc`](home/dot_bashrc.tmpl), which only adds Homebrew,
  and only in interactive shells: `scp`, `rsync`, `ssh host command` and herdr's own
  SSH connection get nothing. An account with none of those login files gets a
  `~/.bash_profile` that reads `~/.bashrc`. Type `herdr`.
- **herdr** ([`config.toml`](home/dot_config/herdr/config.toml.tmpl)) starts new panes
  with `[terminal] default_shell`, set to Homebrew's fish by its full path, because
  herdr can be started over SSH (`herdr --remote`, saved machines) with a minimal
  PATH. On macOS the panes are login shells (herdr's default `shell_mode`). Without
  fish (no Homebrew yet), the setting is left out and herdr falls back to `$SHELL`.
- **herdr's popups** (lazygit on prefix, Alt+G and gh dash on prefix, Alt+H) run as
  `fish -c COMMAND`. herdr starts commands with its own environment, which only
  has what the login shell added: Homebrew. Through fish they get what a pane has:
  `$EDITOR` (so lazygit opens Micro, not vi), the XDG folders, `~/.local/bin`, and
  mise's runtimes (which git hooks that need Node rely on).

### Why the login shells stay zsh and bash

- Nothing has to run `chsh` to fish or add fish to `/etc/shells`, which needs an
  administrator on a managed account, and a broken fish config can't lock you out
  of SSH.
- Everything outside herdr keeps a fast POSIX shell: the shell you type `herdr`
  into, plain `ssh host` sessions, and programs that run `$SHELL -c` (fzf previews,
  coding agents). fish never sets `$SHELL`.
- A few programs open an interactive `$SHELL` and so get the bare login shell:
  `chezmoi cd` is set to open fish instead; in Micro, type `term fish`; for
  `mise en`, add `-s fish`.
- Ghostty's `ssh-env` and `ssh-terminfo` only affect the zsh Ghostty opens. In
  herdr's panes, ssh sends herdr's terminal type (`xterm-256color`), which every
  computer knows.

### Layout and startup order

Every fish, even one that only runs a command, reads the same files in this order:

1. fish's own setup. In a login shell on macOS this includes its copy of
   `path_helper`, which puts the system's folders at the front of PATH.
2. Every file in [`~/.config/fish/conf.d`](home/dot_config/fish/conf.d), in name
   order. These set the environment, for every fish:

   | File                     | What it does                                                        |
   | ------------------------ | ------------------------------------------------------------------- |
   | `00-environment.fish`    | XDG folders first, then tool config paths, `PAGER`, `LESS`, fzf colors |
   | `10-homebrew.fish`       | Homebrew's `brew shellenv fish`, written in when chezmoi applies    |
   | `20-path.fish`           | `~/.local/bin` and mise's shims in front of Homebrew; picks `$EDITOR` |

3. [`config.fish`](home/dot_config/fish/config.fish). Inside
   `if status is-interactive`, so only for shells you type into: the Catppuccin Mocha
   theme built into fish, abbreviations, and the mise, atuin, zoxide and starship
   hooks. Popups and scripts skip all of it.
4. `~/.config/fish/config-local.fish`, if it exists (untracked, see below).

Functions in [`functions/`](home/dot_config/fish/functions) (`update`, `doctor`,
`ff`) and completions in [`completions/`](home/dot_config/fish/completions) load the
first time they're used.
Homebrew's tools bring their own completions, which fish finds by itself; chezmoi
writes chezmoi's and mise's here because both live in `~/.local/bin`.

Nothing prints while fish starts, which matters for SSH. Starting fish to run a
command (`fish -c true`, as each popup does) takes about 7 ms on an Apple silicon
Mac, and an interactive one about 40 ms.

### Where to add things

| To add                       | Put it in                                                            |
| ---------------------------- | -------------------------------------------------------------------- |
| An environment variable      | `conf.d/00-environment.fish`: `set -gx NAME value`                   |
| An abbreviation              | `config.fish`, inside `if status is-interactive`, after `command -q TOOL` |
| A function                   | A new `functions/NAME.fish` holding one `function NAME --description '...'` |
| A completion                 | `completions/COMMAND.fish`                                           |
| Something for one machine    | `~/.config/fish/config-local.fish` (untracked; loads last, in every fish) |

Keep settings global (`set -g`, `set -gx`). Universal variables (`set -U`) live in
`~/.config/fish/fish_variables`, which belongs to each machine and is never tracked.

### Keys and habits

fish's defaults already include autosuggestions (Right or Ctrl-F accepts), syntax
highlighting, tab completion with a menu, typing a folder's path to `cd` into it, and
Emacs-style editing. On top of those:

- Up/Down (and Ctrl-P/Ctrl-N) are fish's own: they search history for commands that
  contain what you typed, move through the Tab menu, and move between the lines of
  a multi-line command.
- Ctrl-R opens atuin's history search. fzf's key bindings are off (yazi, via `ff`,
  covers browsing), so Ctrl-T, Alt-C and Shift-Tab keep fish's own meanings.
- Alt-E opens the command line in your editor.
- Alt-H (or F1) shows the manual page for the command you're typing, and `help`
  opens fish's own documentation.
- Typing `..`, `...`, `....` expands to `cd ../`, `cd ../../` and so on.
- fish keeps a history of the folders you visit: Alt-Left/Alt-Right on an empty
  line move back and forward, `cdh` picks one, `dirh` lists them, and `cd -` goes
  back. `cd` with part of a folder's name jumps there (zoxide).
- Abbreviations (`l`, `ll`, `la`, `lt`, `lr`, `ww`, `fdall`, `rgall`, `dfh`, `du2`,
  `bench`, `y2j`, `j2y`, `bcat`) expand when you press Space or Enter, so
  history keeps the full command. `abbr` lists them.

## Sync dotfiles

```sh
chezmoi update
```

This pulls the repository and applies it. When the Brewfile or mise config changes,
the scripts also install the new packages or runtimes. If chezmoi warns that the
config file template has changed, run `chezmoi init` to regenerate this machine's
config; it only asks questions it hasn't asked before.

A machine still on the earlier zsh setup moves to fish like this, from a shell
outside herdr (a new Ghostty window, or a plain SSH login):

```sh
chezmoi update     # installs fish; on Linux with sudo, switches zsh back to bash
chezmoi init       # picks up fish for `chezmoi cd`
chezmoi apply      # second pass: herdr's config now finds fish
herdr server stop  # the running server keeps its old environment
herdr
```

The first apply removes the zsh files the dotfiles wrote (`~/.zshenv`,
`~/.config/zsh`'s startup files) and, on a Mac, writes `~/.zprofile` at the same
time, so `herdr` stays on PATH. Your own `~/.config/zsh/.zshrc.local` and zsh's
history stay; `install.sh` reminds you to move the settings to fish. On a Linux
account without sudo whose login shell is zsh, ask IT to make it bash, and until then
type `exec bash -l` before `herdr`.

To update everything at once, run `update`, a fish function
([`functions/update.fish`](home/dot_config/fish/functions/update.fish)). It prints
separate Homebrew, chezmoi and mise headings, with distinct colors in a terminal
and plain text when redirected (or when `NO_COLOR` is set). It runs these steps
in order and stops at the first failure:

```sh
brew update
brew upgrade --no-ask
gh extension upgrade --all
chezmoi upgrade
mise self-update --yes
chezmoi update --force --no-tty
mise upgrade --yes
```

gh's extensions are updated in the Homebrew section alongside the shell tools.

The function sets `HOMEBREW_NO_ASK=1` and `MISE_YES=1` for itself and its child
setup scripts, so updates accept confirmations automatically. chezmoi's `--force`
also accepts replacing locally changed managed files with their repository copies.

`mise self-update` comes before `chezmoi update`, so the same run regenerates mise's
tab completion with the updated program. `mise upgrade` upgrades the configured
tools and automatically prunes replaced versions after its grace period.

Run `doctor` to check all three managers with the same headings:

```sh
brew doctor
chezmoi doctor
mise doctor
```

The commands run separately, as with semicolons, so every check runs: Homebrew
reports even warnings with an error exit status, which would stop a chain joined
with `&&`. Both functions check for their programs first and stop with a message
naming any that are missing; `update --help` and `doctor --help` describe them.

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

Every fish puts mise's shims on PATH (`conf.d/20-path.fish`), so scripts and herdr's
popups find the runtimes; interactive shells load full activation in `config.fish` to
switch versions when you change folders. mise's settings, data, state and cache use
the XDG folders; `mise doctor` shows their paths.

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
  installs its fish completion, which fish loads by itself.
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
| `dot_editorconfig`             | Writes `~/.editorconfig`: `dot_` stands for the leading dot.        |
| `dot_config/git/config.tmpl`   | Writes `~/.config/git/config`, filled in as a template (`.tmpl`).   |
| `empty_dot_hushlogin`          | Writes `~/.hushlogin`, keeping it although it's empty (`empty_`).   |
| `create_dot_bash_profile`      | Writes `~/.bash_profile` only if it doesn't exist yet (`create_`).  |
| `symlink_config.yml.tmpl`      | Makes `config.yml` a symlink; the file holds the path it points to. |
| `.config.yml`, or any name starting with a dot | Nothing: chezmoi skips it.                          |

A template is a file with parts between double braces (`{{ ... }}`) that chezmoi fills
in for each machine: for example only its macOS or its Linux part, or the name and
email you gave during setup.

The names starting with `.chezmoi` control chezmoi itself:

- `.chezmoi.toml.tmpl` asks the setup questions and writes each machine's chezmoi
  settings.
- `.chezmoiignore` lists files chezmoi leaves alone: some only on some machines, and
  some, such as `~/.config/fish/config-local.fish`, everywhere.
- `.chezmoiremove` lists files chezmoi deletes: the zsh setup that earlier versions
  of these dotfiles wrote, and fish files that the repository no longer ships.
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
standard MIT license text) and `empty_dot_hushlogin`.

## Validate

GitHub Actions runs three workflows on pushes and pull requests:

- **Shell checks** run ShellCheck and shfmt on plain shell scripts and on chezmoi
  templates rendered for macOS and Linux (x86_64 and ARM64) with both answers to the
  sudo question, fish's syntax check and `fish_indent` on fish files, and actionlint
  on all workflows, then run `scripts/check-shell.py` on macOS and Linux.
- **Bootstrap** runs `install.sh` against the pushed commit on GitHub's macOS runner
  and its x86_64 and ARM64 Ubuntu runners, and in fresh Ubuntu containers on both
  architectures, as a user with sudo and as one without, who answers no to the sudo
  question (Homebrew then goes into the home folder). `scripts/check-install.sh` then
  checks the result: the tools on fish's PATH, `chezmoi verify`, that setup left the
  repository unchanged, the Homebrew prefix, the gh config symlink, gh-dash, the login
  shell and that it finds `herdr`, and that herdr's panes and popups use fish.
- **Secret scan** runs gitleaks over the whole history, which also covers edits made
  without `chezmoi add` and its secret check.

You can also run the checks locally with Python 3.8+, `chezmoi`, `fish` (which brings
`fish_indent`), `shellcheck`, `shfmt` and `actionlint` available, plus `zsh` on macOS
or `bash` on Linux:

```sh
python3 scripts/check-lint.py
python3 scripts/check-shell.py
```

`check-shell.py` renders the fish config and the login shell's startup file, checks
their syntax and fish's formatting, then starts fish as a login and non-login shell
in interactive and noninteractive modes. It verifies quiet SSH-style startup, PATH
priority (including after macOS's path_helper in login shells), Micro selection and
the vi fallback, that interactive settings stay out of scripts and popups, and that
the macOS `zsh -l` (`~/.zprofile`) or Linux interactive `bash` (`~/.bashrc`) gets
Homebrew while `zsh -c` and `bash -c` stay untouched.

Checks use temporary homes and a temporary source copy with Homebrew and editor
stand-ins; other optional shell tools are absent. zsh's system-wide files are
skipped to focus the checks on this repository; bash can't skip its own, so those
run too. The checks do not apply dotfiles, install packages, download external
themes, or use your local shell overrides. Application behavior and integration with
installed tools still need checking on a configured machine.

## To do

These dotfiles don't set up the following yet:

- Docker on Linux, which `lazydocker` and `act` need. macOS installs Docker Desktop.

## License

[MIT](LICENSE). The atuin, btop and gh-dash configs start from the default settings those tools generate; those
parts remain under their projects' licenses.
