# dotfiles

Personal dotfiles for macOS and Linux, managed with [chezmoi](https://www.chezmoi.io/).

## Requirements

- macOS on Apple silicon, or Linux on x86_64 or ARM64.
- Your own user account, not root, with `curl`.
- `~/.local/bin` on your login shell's PATH. Debian and Ubuntu add it in
  `~/.profile` once the folder exists, so log in again after setup; Fedora and
  RHEL add it in `~/.bashrc`. Elsewhere, including macOS, add this line to your
  shell's startup file (`~/.zprofile` for zsh on macOS):

  ```sh
  export PATH="$HOME/.local/bin:$PATH"
  ```

- sudo. Without it, setup installs Homebrew in your home folder on Linux, once
  an administrator has installed the system packages it needs; on a Mac, an
  administrator must install Homebrew in `/opt/homebrew` first.

## Setup

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/seven7thirty3five5/dotfiles/main/install.sh)"
```

Setup asks for your Git name and email, whether this machine publishes dotfile
changes (say yes on one machine only), and whether it may use sudo; the answers
live under `[data]` in `~/.config/chezmoi/chezmoi.toml`. It replaces existing
files it manages, is safe to rerun, and ends with anything left to do by hand.
To preview its changes first:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --use-builtin-git=true seven7thirty3five5
"$HOME/.local/bin/chezmoi" diff --exclude=scripts
```

Then open a new terminal and start `herdr`. In its fish:

- Sign in to GitHub (`gh auth login`), Claude Code and Codex.
- Run `update`, which installs herdr's hooks for Claude Code and Codex, then
  trust the Herdr session hook in Codex's `/hooks`.
- On macOS, open Docker Desktop once to finish its setup.

## Design

### Who owns what

- **chezmoi** owns configuration files and the setup scripts that install
  everything else. Its source state is `home/`, named in `.chezmoiroot`; the
  rest of the repository (`install.sh`, `scripts/`, `skills/` and the
  workflows) is never deployed.
- **Homebrew** owns command-line tools and macOS apps, Claude Code and Codex
  included. The Brewfile is a template with a macOS-only section: setup
  installs what's missing, and `update` upgrades. Without sudo, Homebrew never
  elevates, macOS app bundles go in `~/Applications`, and casks listed in
  `sudo-casks` (Docker Desktop and Logi Options+) are left for an administrator.
- **mise** owns language runtimes and package managers: Node LTS, plus Python,
  uv and pnpm at `latest`, as fallbacks that projects override. mise reads
  `.nvmrc` and `.node-version`; uv owns `.python-version`.
- **`~/.local/bin`** holds the two tools that update themselves outside
  Homebrew: chezmoi, which installs Homebrew, and mise, so runtimes work where
  Homebrew can't be installed (Homebrew's mise would also add its own fish
  activation). Any other new tool goes in the Brewfile, or in mise's config for
  a runtime.
- **Programs that install their own extras** own those files, and the
  repository lists only what to install. gh installs gh-dash, and herdr
  installs its hooks for Claude Code and Codex when `update` runs. The skills
  tool installs the agent skills in the install-skills script from GitHub, so
  `update` brings in pushed changes; one is this repository's
  [`/dotfiles`](skills/dotfiles/SKILL.md), for having an agent change these
  dotfiles.

### Shells

- **Your login shell stays untouched.** The dotfiles never write its startup
  files (`.chezmoiignore` lists them), so skipping herdr leaves you in your own
  shell. It needs only `~/.local/bin` on PATH, where chezmoi links Homebrew's
  herdr once Homebrew has installed it. On macOS, `~/.hushlogin` hides the
  login message.
- **fish inside herdr** holds the environment. herdr starts fish by its full
  path in every pane and runs its popups through it. Every fish, popups
  included, gets the environment from `conf.d`: XDG folders, Homebrew,
  `~/.local/bin` before Homebrew and the system, mise's shims and the editor.
  mise's runtime paths may come first so project versions take priority.
  `config.fish` adds the interactive parts (theme, mise's activation, atuin,
  zoxide, starship),
  and every fish loads the untracked `config-local.fish` last, for settings
  that belong to one machine.

### How setup runs

- **Dotfiles first.** install.sh installs chezmoi, and `chezmoi init --apply`
  writes the dotfiles before the setup scripts run, in number order: Linux
  build tools (with sudo), Homebrew, the Brewfile, gh-dash, mise's runtimes,
  agent skills. A failing script never keeps the dotfiles from being installed.
- **Two applies.** Templates that look for an installed program, such as
  herdr's config for fish and chezmoi's own config for delta, render without
  it on a new machine, so install.sh applies again after the scripts. Each
  such template works without the program. If the first apply fails, setup
  retries its scripts before that final render, so the files and completion
  message see tools installed during recovery too.
- **Scripts rerun when what they install changes.** The packages script embeds
  the Brewfile, the mise script a hash of mise's config, and the skills script
  lists the skills, so editing any of them reinstalls on every machine's next
  apply. Scripts run under `sh`, without fish's environment.
- **Homebrew's possible locations** live in one template, `brew-prefixes`:
  `/opt/homebrew` on macOS, `/home/linuxbrew/.linuxbrew` on Linux, or, without
  sudo, `~/.linuxbrew` or `~/.brew`, which are short enough for Homebrew's
  prebuilt packages.

### Machines

- **One machine publishes.** There, chezmoi commits and pushes each change it
  makes to the repository; other machines pull with `chezmoi update`. The
  repository is public, so chezmoi refuses to add files that look like secrets.
- **Machine state stays local**: fish's universal variables,
  `config-local.fish`, and the agents' settings in `~/.claude` and `~/.codex`.
  gh rewrites its config, so `~/.config/gh/config.yml` links into the
  repository rather than being a copy.
- **One set of global agent instructions** is the exception in the agents'
  folders: `~/.codex/AGENTS.md`, which Codex reads in every session. Claude
  Code reads only `CLAUDE.md`, so `~/.claude/CLAUDE.md` links to it.
- **`update`** upgrades every layer in order (chezmoi and the dotfiles,
  Homebrew, mise, agent skills, gh extensions, herdr's hooks), accepting every
  confirmation and replacing local edits to managed files, and stops at the
  first failure. It upgrades mise's global runtime requests and runs the skills
  update with global Node and pnpm, even from a project with its own versions.
  **`doctor`** checks Homebrew, chezmoi and mise, and the
  sign-ins for Claude Code, Codex and GitHub.

### Look

- **XDG folders** hold configuration, data, state and caches wherever a tool
  supports them, on macOS too, where many tools default to `~/Library` unless
  the XDG variables are set.
- **Catppuccin Mocha**, with the blue accent where a port offers one, themes
  every tool that has a port. `.chezmoiexternal.toml` fetches each port from
  upstream and refreshes it weekly.

### Testing

Every push runs three GitHub Actions workflows. Bootstrap runs install.sh twice
on seven fresh machines (macOS, and Ubuntu on x86_64 and ARM64, with and
without sudo), then `scripts/check-install.sh`. Shell checks lint the scripts
and workflows, check setup permissions, recovery and update scope with recording
commands, and start fish in every mode with and without Homebrew and mise.
Bootstrap also checks that installed integrations start silently. Secret
scan runs gitleaks over the whole history.

## To do

These dotfiles don't set up the following yet:

- Docker on Linux, which `lazydocker` and `act` need. macOS installs Docker Desktop.
