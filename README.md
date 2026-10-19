# dotfiles

Personal dotfiles for macOS and Linux, managed with [chezmoi](https://www.chezmoi.io/).

## Requirements

- A Mac with Apple silicon and sudo, or Linux on x86_64 or ARM64, with or
  without sudo.
- Your own user account, not root, with `curl`.
- `~/.local/bin` on your login shell's PATH. Debian and Ubuntu add it in
  `~/.profile` once the folder exists, so log in again after setup; Fedora and
  RHEL add it in `~/.bashrc`. Elsewhere, including macOS, add this line to your
  shell's startup file (`~/.zprofile` for zsh on macOS):

  ```sh
  export PATH="$HOME/.local/bin:$PATH"
  ```

- On Linux without sudo, an administrator must first install a C compiler,
  `file` and `git`. Setup then installs Homebrew in your home folder without
  ever running sudo. If your home folder's path is too long for Homebrew's
  prebuilt packages, Homebrew's installer says so; an administrator can install
  Homebrew in `/home/linuxbrew/.linuxbrew` instead, and setup uses it.

## Setup

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
```

Setup asks for your Git name and email, whether this machine publishes dotfile
changes (say yes on one machine only), and on Linux whether it may use sudo;
the answers live under `[data]` in `~/.config/chezmoi/chezmoi.toml`. It
replaces existing files it manages, is safe to rerun, and ends with anything
left to do by hand. To preview its changes first:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --use-builtin-git=true seven7thirty3five5
"$HOME/.local/bin/chezmoi" diff --exclude=scripts
```

Then open a new terminal and start `herdr`. In its fish:

- Sign in to GitHub (`gh auth login`), Claude Code and Codex.
- Run `update`, which installs herdr's hooks for Claude Code and Codex, then
  trust the Herdr session hook in Codex's `/hooks`.
- On macOS, open Docker Desktop once to finish its setup.

## How it works

- **chezmoi** writes the files in `home/` (named in `.chezmoiroot`) to your
  home folder; nothing else in the repository is deployed. Templates (`.tmpl`)
  fill in what differs between machines, such as your Git identity, the
  macOS-only packages and Homebrew's folder, which
  `home/.chezmoitemplates/brew-prefix` names from the system and the sudo
  answer.
- **Setup scripts** in `home/.chezmoiscripts` run after the files are written,
  in number order: Linux build tools (with sudo), Homebrew, the Brewfile's
  packages, gh-dash, mise's runtimes and the agent skills. A script runs again
  whenever its text changes, so the packages script embeds the Brewfile and the
  mise script a hash of mise's config.
- **Homebrew** installs the command-line tools and macOS apps in the Brewfile,
  Claude Code and Codex included. **mise** installs Node LTS, plus Python, uv
  and pnpm at `latest`, as fallbacks that projects override; it reads `.nvmrc`
  and `.node-version`, and uv owns `.python-version`. chezmoi and mise live in
  `~/.local/bin`, outside Homebrew; add any other tool to the Brewfile, or to
  mise's config for a runtime.
- **fish runs in herdr** and holds the environment: `conf.d` sets the XDG
  folders (which keep tools out of `~/Library` on macOS), Homebrew,
  `~/.local/bin` before Homebrew, mise's shims and the editor in every fish,
  `config.fish` adds the interactive parts, and the
  untracked `config-local.fish` comes last, for one machine's settings. Your
  login shell's startup files are never touched; it only needs `~/.local/bin`,
  where chezmoi links Homebrew's herdr.
- **One machine publishes.** There, chezmoi commits and pushes each change it
  makes; other machines pull with `chezmoi update`. The repository is public,
  so chezmoi refuses to add files that look like secrets.
- **Machine state stays local**: fish's universal variables,
  `config-local.fish`, and the agents' settings in `~/.claude` and `~/.codex`,
  except the global instructions in `~/.codex/AGENTS.md`, which
  `~/.claude/CLAUDE.md` links to. gh rewrites its config, so
  `~/.config/gh/config.yml` links into the repository.
- **`update`** upgrades everything in order (chezmoi and the dotfiles,
  Homebrew, mise, agent skills, gh extensions, herdr's hooks), accepting every
  confirmation, and stops at the first failure. **`doctor`** checks Homebrew,
  chezmoi and mise, and the sign-ins for Claude Code, Codex and GitHub.
- **Catppuccin Mocha** themes every tool that has a port;
  `.chezmoiexternal.toml` downloads each port from upstream.

To have an agent change these dotfiles, use the
[`/dotfiles`](skills/dotfiles/SKILL.md) skill.

## Checks

Every push runs `.github/workflows/checks.yml`: `scripts/lint.sh` (ShellCheck,
fish's syntax check and actionlint), a gitleaks scan of the whole history, and
install.sh twice on macOS and on a fresh Ubuntu with and without sudo, followed
by `scripts/check-install.sh`.

## To do

- Docker on Linux, which `lazydocker` and `act` need. macOS installs Docker Desktop.
