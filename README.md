# Portable XDG dotfiles

Configuration-only chezmoi repository for macOS and Linux. Audited against 29
`brew leaves` on 2026-09-29. Existing supported configs were retained; missing
configs use defaults. No installation scripts, binaries, credentials, history,
plugin checkouts, or caches are managed. Mole is intentionally unmanaged.
Only LazyVim's `autocmds.lua`, `keymaps.lua`, and `options.lua` are managed for
Neovim; the upstream starter and remaining defaults are installed separately.
Tracked files and directories use ordinary chezmoi permissions, with no
`private_` attributes. These attributes affect filesystem permissions, not GitHub
repository visibility. [Source attributes](https://www.chezmoi.io/reference/source-state-attributes/).

## Recreate on another machine

1. Install zsh, Git, chezmoi, and the tools below using your platform's package
   manager or official releases. Use current versions; `fzf --zsh` requires fzf
   0.48 or newer. Linux package names can differ (`fd-find`, `batcat`, `git-delta`);
   ensure the commands `fd`, `bat`, and `delta` are available under those names.
   On a fresh machine, install the upstream LazyVim starter **before** applying
   chezmoi, since cloning requires an empty destination directory:

   ```sh
   git clone --depth 1 https://github.com/LazyVim/starter.git ~/.config/nvim
   ```

   Skip this clone when LazyVim is already installed. Its `init.lua` and default
   loader are required to start LazyVim even though this repository doesn't track
   them. The next step overlays only the three selected user config files.
2. Apply this public repository over HTTPS; no GitHub login is needed:

   ```sh
   chezmoi init --apply https://github.com/seven7thirty3five5/dotfiles.git
   ```

   First initialization asks for your Git author name and email. On your work
   machine, enter your work email. Answers are saved under `[data]` as `gitName`
   and `gitEmail` in `~/.config/chezmoi/chezmoi.toml`, outside this repository.
   `dot_config/git/config.tmpl` uses them to render `~/.config/git/config`.
   Repeated initialization keeps the saved answers; updates reuse them without
   asking again. Change them with `chezmoi edit-config`, then `chezmoi apply`, or
   run `chezmoi init --prompt --apply` to answer both questions again.
   The config template generates the local chezmoi config; it is not recursively
   managed as an ordinary dotfile.
   [Machine-specific data](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/),
   [initialization prompts](https://www.chezmoi.io/reference/templates/init-functions/promptStringOnce/).
3. Start a new zsh (login or non-login). If desired, make zsh the default shell
   using your OS's supported procedure. No default-shell change is automated.
4. Authenticate gh separately, then recreate the installed extension:

   ```sh
   gh auth login
   gh extension install dlvhdr/gh-dash --pin v4.26.0
   gh dash
   ```

   This was the only installed gh extension at audit time. The pin records the
   observed version without storing its executable. Upgrade deliberately, then
   update this README. [Extension installation](https://cli.github.com/manual/gh_extension_install).
5. Start `nvim` using the upstream LazyVim starter installed in step 1. Its
   default loader downloads lazy.nvim and the default plugins into Neovim's data
   directory. Run `:LazyHealth` and `:checkhealth` to check the setup.
   Only these files come from this repository:

   - `~/.config/nvim/lua/config/autocmds.lua`
   - `~/.config/nvim/lua/config/keymaps.lua`
   - `~/.config/nvim/lua/config/options.lua`

   `init.lua`, `lua/config/lazy.lua`, plugin specs, themes, extras selection,
   `lazyvim.json`, `lazy-lock.json`, `.neoconf.json`, and `stylua.toml` remain
   machine-local or come from the upstream starter. No plugin revisions or
   extra selection are synchronized, so different machines can use different
   upstream default versions. [LazyVim installation](https://www.lazyvim.org/installation).

   Language servers, formatters, parser builds, and Mason packages are separate
   installations. Install the dependencies reported by health checks; they can
   vary by OS and selected language. Neither plugin versions nor system
   packages or downloaded language tools are pinned by this repository. For Node, keep using standalone
   pnpm-managed runtimes or a project version manager; do not install Node or
   pnpm globally. The existing pnpm directory is added to PATH but never installed
   or managed by this repo.
6. Configure Docker separately if using lazydocker. Docker credentials, contexts,
   plugins, and daemon installations are not included. Atuin sync/login is also
   separate; this repo neither exports nor imports history or account keys.

For Homebrew users, the observed common formula names are:

```sh
brew install ast-grep atuin bat btop chezmoi difftastic duf dust eza fd fzf \
  gh git git-delta glow herdr hyperfine lazydocker lazygit neovim ripgrep \
  starship superfile tree-sitter-cli yq zoxide zsh-autosuggestions \
  zsh-syntax-highlighting
```

This is an inventory, not a guarantee that every formula has a bottle on every
Linux distribution/architecture. Prefer an official Linux release or source build
where needed. Some integrations (especially LazyVim) need additional dependencies
such as a C compiler and build tools. Built-in themes come from each application;
track custom theme source files, not generated theme caches.

## Files for every leaf

All paths below are relative to `~/.config/` unless otherwise specified.
Environment-only settings live in the tracked zsh files, not invented per-tool
config files. Files described as optional assets should be added explicitly when
created; chezmoi does not automatically track future files.

| Tool | Tracked configuration / supported alternatives | Shell setup and notes |
| --- | --- | --- |
| ast-grep | No user-global file created. `sgconfig.yml`, rule YAML, tests and custom grammar references belong to each project. | No init. Use `ast-grep`; `sg` can collide with the Linux group-switching utility. [Project config](https://ast-grep.github.io/guide/project/project-config.html). |
| atuin | `atuin/config.toml`; existing `enter_accept = true` retained. | `atuin init zsh` in `.zshrc`, after fzf; owns Ctrl-R and Up. Do not track databases, `key`, or `session`. [Config](https://docs.atuin.sh/configuration/config/), [init](https://docs.atuin.sh/main/reference/init/). |
| bat | `bat/config` (comment-only). Optional custom `bat/themes/*.tmTheme` and `bat/syntaxes/*.sublime-syntax`. | `BAT_CONFIG_DIR` in `.zshenv` ensures the same directory on both OSes. Rebuild generated caches with `bat cache --build` after adding assets; do not track caches. [Config and assets](https://github.com/sharkdp/bat#configuration-file). |
| btop | `btop/btop.conf`; optional custom `btop/themes/*.theme`. | No init. Existing built-in Default theme retained. GUI changes may rewrite the config: re-add deliberate changes. Hardware-specific metrics differ between macOS and Linux. [Config](https://github.com/aristocratos/btop#configurability). |
| chezmoi | `.chezmoi.toml.tmpl` in the repository generates `chezmoi/chezmoi.toml`. Repository `.chezmoiignore` controls platform exclusions. | No init in zsh. Source repo defaults to `~/.local/share/chezmoi`; state databases stay local. [Setup](https://www.chezmoi.io/user-guide/setup/). |
| difftastic | No native config file. Optional environment variables go in zsh; current opt-in Git difftool definition is in `git/config`. | No init. Run `git difftool --tool=difftastic`. Keep ordinary textual diffs for patches and staging. [Git integration](https://difftastic.wilfred.me.uk/git.html). |
| duf | No supported user config file found; CLI flags select display/filtering. | No init. Do not invent a duf config. [Usage](https://github.com/muesli/duf#usage). |
| dust | `dust/config.toml` (comment-only); legacy `~/.dust.toml` is unnecessary. | No init. Reports per-directory usage, complementing duf's filesystem capacity view. [Config](https://github.com/bootandy/dust#config-file). |
| eza | `eza/theme.yml` (`{}` preserves built-in colors). | `EZA_CONFIG_DIR` in `.zshenv` avoids macOS's Application Support default. No init. Icons require a suitable font. [Themes](https://github.com/eza-community/eza-themes#installation). |
| fd | `fd/ignore` (comment-only global ignore patterns). Project `.fdignore` files belong with their projects. | No init. No native global options config; it supplies fzf candidates. [Manual](https://github.com/sharkdp/fd/blob/master/doc/fd.1). |
| fzf | No automatically read config file created. `FZF_*` variables live in `.zshrc`; `FZF_DEFAULT_OPTS_FILE` is supported if an options file is wanted later. | `source <(fzf --zsh)` after compinit. Disable its Ctrl-R during sourcing; retain Ctrl-T and Alt-C. [Shell integration](https://github.com/junegunn/fzf#setting-up-shell-integration). |
| gh | `gh/config.yml` only; aliases/settings included. Never add `gh/hosts.yml`. | No required init. gh-dash also has its own `gh-dash/config.yml`, retained here. Extension binaries under data storage are excluded. [gh config](https://cli.github.com/manual/gh_config), [gh-dash](https://github.com/dlvhdr/gh-dash). |
| git | `git/config` rendered from `dot_config/git/config.tmpl`, plus `git/ignore`; per-machine identity, delta settings and opt-in difftastic. | No init. XDG config/ignore paths are natively supported. Project `.gitconfig` includes, signing keys and credential stores require separate consideration if added. [Git config](https://git-scm.com/docs/git-config). |
| git-delta | Settings in `git/config`, no invented standalone config. Optional custom themes can be a separate Git include file. | No init. `core.pager` and `interactive.diffFilter` enable delta. lazygit also explicitly uses delta; built-in delta themes require no copied assets. [Configuration](https://dandavison.github.io/delta/configuration.html). |
| glow | `glow/glow.yml` (`{}` preserves defaults); optional custom renderer style JSON, referenced through `style`. | No init. Explicit XDG_CONFIG_HOME is recognized on macOS. [Config discovery source](https://github.com/charmbracelet/glow/blob/master/main.go). |
| herdr | `herdr/config.toml`; existing built-in catppuccin theme and onboarding setting retained. No installed custom plugins found (empty `.plugins.lock`). | No required shell init. Do not track session JSON, sockets, logs or release metadata, even where they live under `.config`. [Configuration](https://herdr.dev/docs/configuration/). |
| hyperfine | No supported global config file; benchmark flags and export destinations are command arguments. | No init. Benchmark recipes belong with projects. [Usage](https://github.com/sharkdp/hyperfine#usage). |
| lazydocker | `lazydocker/config.yml` (`{}` preserves defaults). | `.zshrc` defines a command wrapper that scopes supported `CONFIG_DIR` to this command. Avoid exporting this generic name globally. Direct invocations outside the shell wrapper must pass that override if their defaults resolve elsewhere. [Discovery source](https://github.com/jesseduffield/lazydocker/blob/master/pkg/config/app_config.go), [config](https://github.com/jesseduffield/lazydocker/blob/master/docs/Config.md). |
| lazygit | `lazygit/config.yml`, retaining the existing delta diff renderer. | No init; explicit XDG_CONFIG_HOME selects the XDG path on macOS. Requires delta for the configured renderer. `state.yml` is runtime state; repository overrides belong to projects. [Config](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md). |
| mole | Intentionally unmanaged; no Mole files are tracked. | Optional macOS-only app, with no shell init. Local settings are left alone. |
| neovim | Only `nvim/lua/config/autocmds.lua`, `nvim/lua/config/keymaps.lua`, and `nvim/lua/config/options.lua`. | No shell init; `EDITOR`/`VISUAL` are set in `.zshenv`. Install the default LazyVim starter separately before applying these files; remaining Neovim files and plugins are unmanaged. [LazyVim](https://www.lazyvim.org/installation). |
| ripgrep | `ripgrep/config` (comment-only), selected with `RIPGREP_CONFIG_PATH`; project `.rgignore` files remain project-owned. | Export the path in `.zshenv`; ripgrep does not discover an arbitrary dotfile itself. Keep defaults to avoid changing LazyVim's searches. [Configuration](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file). |
| starship | `starship.toml` (comment-only); custom prompt palettes belong inside it. | `STARSHIP_CONFIG` in `.zshenv`; `starship init zsh` in `.zshrc` after navigation/history widgets and before the final plugins. No second prompt framework. [Config](https://starship.rs/config/). |
| superfile | `superfile/config.toml`, `superfile/hotkeys.toml`; custom `superfile/theme/*.toml` if added. | No required init. Installed v1.6.0 honors explicit XDG config/data/state variables. Minimal main config uses supported `ignore_missing_fields = true` to inherit built-in settings and keybindings without warnings. Built-in themes are generated by spf, not tracked as custom themes. Optional cd-on-quit needs a shell wrapper; left disabled. [Config](https://superfile.dev/configure/superfile-config/), [installed path source](https://github.com/yorukot/superfile/blob/v1.6.0/src/config/fixed_variable.go). |
| tree-sitter-cli | `tree-sitter/config.json` with empty parser-directory list and theme map. | No init. Add actual grammar source directories when using CLI parse/highlight; an empty list may warn for grammar discovery and is intentional. Project `tree-sitter.json` and grammars belong in their repos, not dotfiles. [CLI config](https://tree-sitter.github.io/tree-sitter/cli/init-config.html). |
| yq | No supported global config file for Homebrew's Mike Farah yq. | No init. Do not confuse it with the Python/jq-wrapper yq: their command syntax differs. [Docs](https://mikefarah.gitbook.io/yq). |
| zoxide | No native config file; options/environment in zsh. | `zoxide init zsh --cmd cd` replaces interactive `cd` and adds `cdi` (fzf picker). `_ZO_DATA_DIR` selects XDG data storage on both OSes; its database stays local. `builtin cd` bypasses the wrapper. [Configuration](https://github.com/ajeetdsouza/zoxide#configuration). |
| zsh-autosuggestions | Settings belong in `.zshrc`; no dedicated native config file. | Source after widget integrations, before syntax highlighting. Default suggestions use zsh's native history, while Atuin provides searchable history. [Config](https://github.com/zsh-users/zsh-autosuggestions#configuration). |
| zsh-syntax-highlighting | Settings belong in `.zshrc`; no dedicated native config file. | Source last, after compinit, keybindings and other widget plugins. [Required order](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md). |

## Zsh startup and ordering

`~/.zshenv` is a relative symlink to `.config/zsh/.zshenv`, so zsh can discover
`ZDOTDIR` before loading later files. The XDG variables use their standard paths;
`XDG_RUNTIME_DIR` is deliberately left to the OS/session because a persistent
home-directory substitute would violate its lifetime/ownership requirements.

1. `.zshenv`: XDG paths, ZDOTDIR, supported tool config-path overrides, editor,
   and static PATH entries. No external commands, output, prompt hooks or widgets.
   This file runs in scripts too. Known Homebrew locations support Apple Silicon,
   Intel macOS and Linuxbrew. User binaries and existing pnpm/Docker paths are
   portable and deduplicated.
2. `.zprofile`: login shells only; guarded `brew shellenv` supplies Homebrew's
   additional environment. Non-login shells still have the static PATH setup.
3. `.zshrc`: interactive shells only; initialize history and XDG cache directories,
   add package/Docker completion paths, then run `compinit` once with its dump
   under `~/.cache/zsh`.
4. Initialize fzf with Ctrl-R disabled, then Atuin, then zoxide replacing `cd`,
   then Starship. Define the lazydocker scoped-config wrapper.
5. Source zsh-autosuggestions, then zsh-syntax-highlighting last. Plugin discovery
   supports Homebrew, common Linux distro locations, or manual checkouts under
   `~/.local/share/zsh/plugins/<plugin>/`. These checkouts are installations and
   are not tracked. There is no plugin manager to initialize.

No tool needs `.zlogin` or `.zlogout`; no empty files were created for them.
No miscellaneous aliases or navigation functions are included. Prior aliases
were retired to a local backup, including aliases for tools not in the inventory.

## Interactions and limits

- Atuin and fzf compete for Ctrl-R; Atuin now owns it. fzf retains Ctrl-T/Alt-C,
  also powers zoxide's `cdi`, and uses fd for candidates. Atuin's Up binding can
  be disabled later with `atuin init zsh --disable-up-arrow` if desired.
- Atuin and native zsh history are separate stores. Autosuggestions still uses
  native history; it does not automatically query Atuin's database. Native history
  lives under `~/.local/state/zsh/history`. Neither history store is versioned.
- zoxide changes interactive navigation semantics: names can resolve to ranked
  remembered directories. `builtin cd` preserves normal shell behavior. Scripts
  do not load the interactive replacement.
- delta formats textual diffs; difftastic computes structural diffs. They are
  configured as separate workflows, rather than forcing structural output through
  delta. Git, lazygit, and gh-dash cover different tasks: local repository commands,
  local interactive staging, and GitHub PR/issue review. gh-dash can use a delta
  diff pager explicitly if customized later.
- ripgrep and fd complement LazyVim's search/file pickers; global ignore changes
  affect shell results and integrations. ast-grep is structural search and rewriting,
  using tree-sitter grammars; it does not automatically adopt Neovim's parsers.
  The tree-sitter CLI and Neovim's parser plugins have distinct configs and builds.
- duf reports filesystem free space; dust shows which directories consume space;
  btop monitors processes/resources; Mole changes/removes macOS data. Cleaning
  caches with Mole may require rebuilding bat caches, parsers or other tool assets.
  These generated assets should stay outside chezmoi.
- Installed font/terminal support affects icons, prompt glyphs and theme colors.
  Built-in themes are represented by config choices or application defaults;
  copying every built-in theme is unnecessary. Add custom theme source files only
  for tools you intend to manage; Neovim themes remain unmanaged.
- Previously configured required Git LFS filters were removed because `git-lfs`
  was absent. If an LFS repository needs it, install git-lfs separately and run
  `git lfs install`; then explicitly track the generated filter config if desired.
- The public repository reads Git identity from machine-local chezmoi data;
  work email is never committed by this setup. Earlier history and commit metadata
  contain the original personal Git identity. gh authentication, Atuin keys,
  signing keys and other credentials remain machine-local. Do not run
  `chezmoi add ~/.config` indiscriminately; add only reviewed config/asset paths.

## Maintaining the repository

After editing a managed config, run `chezmoi add <path>` to update its source copy,
then `chezmoi diff`, review, commit, and push from `chezmoi cd`. After a deliberate
LazyVim change, re-add only the selected `autocmds.lua`, `keymaps.lua`, and
`options.lua` files. The ignore rules exclude the rest of Neovim and all Mole
files; avoid overriding those rules. After adding a custom theme for another
managed tool, explicitly add that asset and its selecting config.
Use `chezmoi update` on other machines to pull and apply the committed config.
The same tool versions may still be needed to reproduce behavior exactly.

## Validation

- Chezmoi init/apply and matching source/destination state on macOS.
- Fresh macOS login/interactive zsh: Atuin owns Ctrl-R; cd/cdi are zoxide functions;
  supported XDG config overrides resolve correctly; lazydocker parses its config.
- Linux target rendered with chezmoi's OS data override, then actual zsh startup
  tested in a disposable Debian-based Docker container with tools absent. Confirmed
  XDG paths, ZDOTDIR, state/cache locations and missing-tool guards. Mole is now unmanaged on every OS.
- bat, eza, dust, ripgrep, Glow, Starship, tree-sitter config loading on macOS;
  superfile v1.6.0 opened successfully with minimal config/hotkeys and exited cleanly.
- JSON/TOML/YAML syntax and Neovim Lua syntax checked before publishing.

Linux validation covers shell startup and target layout, not full interactive
execution of every application or LazyVim language-tool installation on Linux.

The Git identity template was additionally checked with a separate work identity,
including names with spaces, quotes and backslashes, and repeated initialization
was checked to preserve the saved machine-local identity without prompting.

Following the tracking-scope change, macOS and Linux target layouts were checked
to contain only the three selected Neovim files, no Mole files, and no private
source attributes. Existing local Mole and default LazyVim files are preserved.
