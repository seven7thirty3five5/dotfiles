# Portable XDG dotfiles

Chezmoi configurations for macOS (Apple silicon) and Linux.

## Set up a new machine

Run one command. It asks for your Git name and email, and whether this machine should
commit and push dotfile changes; answer yes only on the machine you publish from.

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
```

[`install.sh`](install.sh) runs `chezmoi init --apply`, and the scripts in
[`home/.chezmoiscripts`](home/.chezmoiscripts) set the machine up in this order:

1. **Homebrew**, if it is missing:
   - macOS (Apple silicon): `/opt/homebrew` is the only supported prefix. Installing
     it requires sudo access; without it, setup stops and asks for an administrator
     to install Homebrew there. An existing installation is reused without sudo.
     Homebrew installs Apple's Command Line Tools when needed. Intel Macs are not
     supported by these dotfiles.
   - Linux with sudo: `/home/linuxbrew/.linuxbrew`. Setup first installs the build
     tools Homebrew requires, plus zsh and unzip, with `apt-get`, `dnf` or `pacman`.
   - Without sudo on Linux: `~/.linuxbrew`, or `~/.brew` when that path would be longer
     than the default. Homebrew uses its prebuilt bottles in a custom prefix only if it
     is no longer than the default ([support tiers](https://docs.brew.sh/Support-Tiers)).
     A C compiler, `file` and zsh must then come from your administrator.
2. **The [Brewfile](home/dot_config/homebrew/Brewfile)**, with `brew bundle --no-upgrade`.
   Mole, GNU tar and the Ghostty cask are macOS-only; the cask adopts an existing
   Ghostty app.
3. **The dotfiles** themselves.
4. **[gh-dash](https://www.gh-dash.dev/)**, the GitHub CLI extension.
5. **LazyVim's plugins**, headless, at the versions in `lazy-lock.json`.
6. **zsh as the login shell**, with `chsh` when zsh is listed in `/etc/shells`;
   otherwise it says what to ask an administrator for.

`install.sh` then initializes Homebrew in its own shell and runs `chezmoi init` once
more so chezmoi's own config picks up `delta` and `nvim`. Re-running it is safe, and
extra arguments are passed to `chezmoi init`.

### After setup

- Open a new terminal.
- Run `gh auth login` before using `gh dash`; installing it needed no login.
- In Neovim, `:LazyHealth` and `:checkhealth mason` report anything still missing.
  Language servers that need Node use your pnpm-managed runtime; Node and pnpm are
  not installed by the Brewfile.
- Ghostty bundles JetBrains Mono and the Nerd Font symbols. Over SSH, LazyVim, lazygit,
  eza and gh-dash icons need a Nerd Font (v3 or newer) in the connecting terminal.
- `lazydocker` needs a working Docker installation, which you set up separately.
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

## Validate

GitHub Actions runs three workflows on pushes and pull requests:

- **Shell checks** test the bootstrap prefix policy, sudo requirements and installer
  PATH propagation with stand-ins, then run `scripts/check-shell.py` on macOS and
  Linux, as described below.
- **Bootstrap** runs `install.sh` against the pushed commit on GitHub's macOS and
  Ubuntu runners, and in fresh Ubuntu containers as a user with sudo and as one
  without (Homebrew then goes into the home folder). `scripts/check-install.sh` then
  checks the result: the tools on PATH, `chezmoi verify`, the Homebrew prefix, the
  symlinks, gh-dash and LazyVim's plugins.
- **Secret scan** runs gitleaks over the whole history, which also covers edits made
  without `chezmoi add` and its secret check.

You can also run the shell checks locally with Python 3.8+, `chezmoi`, and `zsh`
available:

```sh
python3 scripts/check-bootstrap.py
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
