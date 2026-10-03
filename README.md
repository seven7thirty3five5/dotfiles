# Portable XDG dotfiles

Configuration-only chezmoi repository for macOS and Linux. Covers 28 tools from
`brew leaves` on 2026-09-29. Existing supported configs were retained; missing
configs use defaults. No installation scripts, binaries, credentials, history,
plugin checkouts, or caches are managed.
The complete LazyVim configuration under `~/.config/nvim` is managed, including
plugin specifications, extras selection, and `lazy-lock.json`.
Tracked files and directories use ordinary chezmoi permissions, with no
`private_` attributes. These attributes affect filesystem permissions, not GitHub
repository visibility. [Source attributes](https://www.chezmoi.io/reference/source-state-attributes/).

This repository makes these assumptions:

- [Homebrew](https://docs.brew.sh/Installation) is the package manager for the
  development tools whose configurations are tracked here, on macOS and Linux.
- zsh is the shell used for startup files and tool integrations.
- The [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
  is followed as much as possible, using its standard config/data/state/cache paths.

Files that need to live in the home directory stay there: the zsh bootstrap
`~/.zshenv` and the tracked `~/.editorconfig`. EditorConfig sets UTF-8, LF line
endings, and a final newline; closer project files can override these defaults.
[EditorConfig discovery and precedence](https://editorconfig.org/#file-location).

`~/.aliases` and `~/.functions` are per-machine customizations. They are deliberately
excluded from chezmoi and this repository; `.zshrc` sources them first, in that
order, when present. On another machine, create them locally with
`touch ~/.aliases ~/.functions` and add that machine's aliases and functions.

## Recreate on another machine

1. Install Homebrew and ensure zsh, Git, and chezmoi are available before applying
   the repository. Install the development-tool inventory below with Homebrew.
   Use current versions; `fzf --zsh` requires fzf 0.48 or newer.
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
3. Start a new zsh. On macOS, use a login shell (`exec zsh -l`) for a fresh
   session so `.zprofile` initializes Homebrew; subsequent non-login shells
   inherit that environment. Linux initializes Homebrew in interactive `.zshrc`.
   If desired, make zsh the default shell using your OS's supported procedure.
   No default-shell change is automated.
4. Authenticate gh separately, then recreate the installed extension:

   ```sh
   gh auth login
   gh extension install dlvhdr/gh-dash --pin v4.26.0
   gh dash
   ```

   This was the only installed gh extension at audit time. The pin records the
   observed version without storing its executable. Upgrade deliberately, then
   update this README. [Extension installation](https://cli.github.com/manual/gh_extension_install).
5. Start `nvim`. The tracked `init.lua` and `lua/config/lazy.lua` bootstrap
   lazy.nvim and LazyVim into Neovim's data directory. The full configuration
   tree is tracked, including Lua configuration and plugin specs, `lazyvim.json`,
   `lazy-lock.json`, `.neoconf.json`, and `stylua.toml`; no separate starter clone
   is needed. Run `:Lazy restore` to install the plugin revisions recorded in
   the lockfile, then `:LazyHealth` and `:checkhealth` to check the setup.
   [LazyVim configuration](https://www.lazyvim.org/configuration/general),
   [lockfile restoration](https://lazy.folke.io/usage/lockfile).

   Language servers, formatters, parser builds, and Mason packages are separate
   installations. Install the dependencies reported by health checks; they can
   vary by OS and selected language. Plugin checkouts, downloaded tools, caches,
   and state stay outside this repository.
6. Configure Docker separately if using lazydocker. Docker credentials, contexts,
   plugins, and daemon installations are not included. Atuin sync/login is also
   separate; this repo neither exports nor imports history or account keys.

Install the development-tool inventory with these Homebrew formula names:

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

Starship's config lives at `~/.config/starship/config.toml`, selected by
`STARSHIP_CONFIG` in `env.zsh`. Applying the repo removes the former
`~/.config/starship.toml` path.

Superfile v1.6.0 saves hidden-file visibility in
`~/.local/share/superfile/toggleDotFile`, rather than a TOML option. This single
preference is tracked with the exact contents `true` and no trailing newline,
so hidden files start visible on each machine. The EditorConfig exception keeps
that format intact; other superfile data, caches, and state remain unmanaged.
[Preference loading](https://github.com/yorukot/superfile/blob/v1.6.0/src/internal/config_function.go),
[preference format](https://github.com/yorukot/superfile/blob/v1.6.0/src/pkg/utils/bool_file_store.go).

## Configuration file support

Support includes project configs, ignore/theme files, and options files selected
through supported environment variables. gh-dash and LazyVim are listed alongside
their host tools.

The environment column covers runtime controls, including color, authentication,
and diagnostics. Shared OS variables such as `HOME`, `PATH`, and `XDG_*` are
omitted, as are build/test-harness variables and arbitrary data read by expressions
or templates. Linked `*` families refer to the supported names in the upstream
reference; a prefix alone does not make an arbitrary variable supported. Zsh
plugins use shell variables, marked below, including arrays that cannot be exported.
Other extensions and plugins can define their own additional controls.

| Tool | Supported | Custom environment variables |
| --- | --- | --- |
| [ast-grep](https://ast-grep.github.io/) | [yes](https://ast-grep.github.io/guide/project/project-config.html) | [`NO_COLOR`](https://github.com/ast-grep/ast-grep/blob/main/crates/cli/src/print/colored_print/styles.rs) |
| [atuin](https://docs.atuin.sh/latest/) | [yes](https://docs.atuin.sh/latest/configuration/config/) | [`ATUIN_*`](https://github.com/atuinsh/atuin/tree/main/crates) (config overrides, config/theme paths, shell bindings, history context, logging); [`NO_COLOR`](https://github.com/atuinsh/atuin/blob/main/crates/atuin/src/command/client/output/search/mod.rs), [`NO_MOTION`](https://github.com/atuinsh/atuin/blob/main/crates/atuin-client/src/settings.rs) |
| [bat](https://github.com/sharkdp/bat) | [yes](https://github.com/sharkdp/bat#configuration-file) | [`BAT_*` option overrides](https://github.com/sharkdp/bat/blob/master/src/bin/bat/config.rs); [`BAT_CONFIG_DIR`, `BAT_CACHE_PATH`](https://github.com/sharkdp/bat/blob/master/src/bin/bat/directories.rs); [`NO_COLOR`](https://github.com/sharkdp/bat/blob/master/src/bin/bat/app.rs) |
| [btop](https://github.com/aristocratos/btop) | [yes](https://github.com/aristocratos/btop#configurability) | [`BTOP_SNAPPED`](https://github.com/aristocratos/btop/blob/main/src/osx/btop_collect.cpp) (macOS/BSD collector override) |
| [chezmoi](https://www.chezmoi.io/) | [yes](https://www.chezmoi.io/reference/configuration-file/) | [`CHEZMOI_GITHUB_ACCESS_TOKEN`, `CHEZMOI_GITHUB_TOKEN`, `GITHUB_ACCESS_TOKEN`, `GITHUB_TOKEN`](https://www.chezmoi.io/reference/commands/upgrade/); [`NO_COLOR`, `EJSON_KEYDIR`](https://github.com/twpayne/chezmoi/blob/master/internal/cmd/config.go); optional integrations: [`BW_SESSION`](https://github.com/twpayne/chezmoi/blob/master/internal/cmd/bitwardentemplatefuncs.go), [`OP_SESSION_<account>`, `OP_CONNECT_HOST`, `OP_CONNECT_TOKEN`, `OP_SERVICE_ACCOUNT_TOKEN`](https://github.com/twpayne/chezmoi/blob/master/internal/cmd/onepasswordtemplatefuncs.go) |
| [difftastic](https://difftastic.wilfred.me.uk/introduction.html) | no | [`DFT_*`](https://github.com/Wilfred/difftastic/tree/master/src) (display/limits, numbered syntax overrides, diagnostics) |
| [duf](https://github.com/muesli/duf) | no | [`NO_COLOR`, `CLICOLOR_FORCE`](https://github.com/muesli/termenv#color-support) (through its termenv color detection) |
| [dust](https://github.com/bootandy/dust) | [yes](https://github.com/bootandy/dust#config-file) | [`NO_COLOR`](https://github.com/bootandy/dust/blob/master/src/main.rs) |
| [eza](https://github.com/eza-community/eza) | [yes](https://github.com/eza-community/eza-themes#installation) | [`EZA_*`, `LS_COLORS`, `NO_COLOR`](https://github.com/eza-community/eza/blob/main/man/eza.1.md#environment-variables); legacy [`EXA_*`](https://github.com/eza-community/eza/blob/main/src/options/vars.rs) fallbacks |
| [fd](https://github.com/sharkdp/fd) | [yes](https://github.com/sharkdp/fd#excluding-specific-files-or-directories) | [`LS_COLORS`, `NO_COLOR`](https://github.com/sharkdp/fd#colorized-output) |
| [fzf](https://junegunn.github.io/fzf/) | [yes](https://github.com/junegunn/fzf#environment-variables) | [`FZF_*` core options/API controls, `NO_COLOR`](https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1); [`FZF_*` shell integration and tmux controls](https://junegunn.github.io/fzf/shell-integration/) |
| [gh](https://cli.github.com/manual/) | [yes](https://cli.github.com/manual/gh_help_environment) | [`GH_*`, `GITHUB_TOKEN`, `GITHUB_ENTERPRISE_TOKEN`, `GLAMOUR_STYLE`, `NO_COLOR`, `CLICOLOR`, `CLICOLOR_FORCE`](https://cli.github.com/manual/gh_help_environment) |
| [gh-dash](https://www.gh-dash.dev/getting-started/) | [yes](https://www.gh-dash.dev/configuration/) | [`GH_DASH_CONFIG`](https://github.com/dlvhdr/gh-dash/blob/main/internal/config/parser.go), [`LOG_LEVEL`](https://github.com/dlvhdr/gh-dash/blob/main/cmd/root.go), [`DASH_PROFILE`](https://github.com/dlvhdr/gh-dash/blob/main/gh-dash.go); gh authentication variables above |
| [git](https://git-scm.com/docs) | [yes](https://git-scm.com/docs/git-config) | [`GIT_*`, `EMAIL`, `SSH_ASKPASS`](https://git-scm.com/docs/git#_environment_variables) |
| [git-delta](https://dandavison.github.io/delta/) | [yes](https://dandavison.github.io/delta/configuration.html) | [`DELTA_*`](https://github.com/dandavison/delta/tree/main/src) (features, navigation, pager, diagnostics), [`BAT_THEME`](https://github.com/dandavison/delta/blob/main/src/env.rs); [`BAT_PAGER`, `GIT_PAGER`](https://dandavison.github.io/delta/environment-variables.html) |
| [glow](https://github.com/charmbracelet/glow) | [yes](https://github.com/charmbracelet/glow#the-config-file) | [`GLOW_*`](https://github.com/charmbracelet/glow/blob/main/main.go) (config-key overrides and `GLOW_CONFIG_HOME`); [`GLOW_TEXT_SIZING`](https://github.com/charmbracelet/glow/blob/main/utils/textsize.go) |
| [herdr](https://herdr.dev/docs/) | [yes](https://herdr.dev/docs/configuration/) | [`HERDR_*`](https://herdr.dev/docs/cli-reference/#environment-variables) (config/session/socket overrides, process detection, logging, sound, pane context) |
| [hyperfine](https://github.com/sharkdp/hyperfine) | no | [`NO_COLOR`](https://github.com/sharkdp/hyperfine/blob/master/src/options.rs) |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | [yes](https://github.com/jesseduffield/lazydocker/blob/master/docs/Config.md) | [`CONFIG_DIR`, `DEBUG`](https://github.com/jesseduffield/lazydocker/blob/master/pkg/config/app_config.go), [`LOG_LEVEL`](https://github.com/jesseduffield/lazydocker/blob/master/pkg/log/log.go); [`DOCKER_HOST`, `DOCKER_CONTEXT`, `DOCKER_CERT_PATH`, `DOCKER_TLS_VERIFY`](https://github.com/jesseduffield/lazydocker/blob/master/pkg/commands/docker.go) |
| [lazygit](https://github.com/jesseduffield/lazygit) | [yes](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md) | [`LG_CONFIG_FILE`, `CONFIG_DIR`, `LAZYGIT_KEYBINDING_PLATFORM`, `LAZYGIT_LOG_PATH`](https://github.com/jesseduffield/lazygit/blob/master/pkg/config/app_config.go); [`DEBUG`](https://github.com/jesseduffield/lazygit/blob/master/pkg/app/entry_point.go), [`LOG_LEVEL`](https://github.com/jesseduffield/lazygit/blob/master/pkg/logs/logs.go), [`GH_PATH`](https://github.com/jesseduffield/lazygit/blob/master/pkg/commands/git_commands/github.go), [`SHOW_RECENT_REPOS`](https://github.com/jesseduffield/lazygit/blob/master/pkg/app/app.go), [`LAZYGIT_NEW_DIR_FILE`](https://github.com/jesseduffield/lazygit/blob/master/pkg/gui/controllers/helpers/record_directory_helper.go), [`LAZYGIT_SLOW_RENDER`](https://github.com/jesseduffield/lazygit/blob/master/pkg/tasks/tasks.go); Git variables above |
| [neovim](https://neovim.io/doc/user/) | [yes](https://neovim.io/doc/user/starting/#config) | [`NVIM_APPNAME`, `NVIM_LOG_FILE`, `VIMINIT`, `EXINIT`, `VIM`, `VIMRUNTIME`](https://neovim.io/doc/user/starting/); [`NVIM_RPLUGIN_MANIFEST`](https://neovim.io/doc/user/remote_plugin/); [`NVIM_PYTHON_LOG_FILE`, `NVIM_PYTHON_LOG_LEVEL`](https://github.com/neovim/pynvim#troubleshooting) |
| [LazyVim](https://www.lazyvim.org/) | [yes](https://www.lazyvim.org/configuration/general) | [`MASON`](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/init.lua), [`CC`](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/treesitter.lua); Neovim variables above |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | [yes](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file) | [`RIPGREP_CONFIG_PATH`](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file), [`NO_COLOR`](https://github.com/BurntSushi/ripgrep/blob/master/crates/core/flags/defs.rs) |
| [starship](https://starship.rs/) | [yes](https://starship.rs/config/) | [`STARSHIP_CONFIG`, `STARSHIP_CACHE`, `STARSHIP_SESSION_KEY`](https://starship.rs/config/#logging), [`STARSHIP_LOG`](https://github.com/starship/starship/blob/main/src/logger.rs), [`STARSHIP_NUM_THREADS`](https://github.com/starship/starship/blob/main/src/lib.rs), [`STARSHIP_SHELL`](https://github.com/starship/starship/blob/main/src/context/mod.rs); modules also read their tools' environment |
| [superfile](https://superfile.dev/) | [yes](https://superfile.dev/configure/superfile-config/) | None |
| [tree-sitter-cli](https://tree-sitter.github.io/tree-sitter/cli/) | [yes](https://tree-sitter.github.io/tree-sitter/cli/init-config.html) | [`TREE_SITTER_DIR`](https://github.com/tree-sitter/tree-sitter/blob/master/crates/config/src/tree_sitter_config.rs); [`TREE_SITTER_LIBDIR`, `TREE_SITTER_WASI_SDK_PATH`, `TREE_SITTER_BINARYEN_PATH`](https://github.com/tree-sitter/tree-sitter/blob/master/crates/loader/src/loader.rs); [`TREE_SITTER_*` playground controls](https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/src/playground.rs), [`TREE_SITTER_*` fuzz/logging controls](https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/src/fuzz.rs); [`NO_COLOR`](https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/src/paint.rs) |
| [yq](https://mikefarah.gitbook.io/yq) | no | [`NO_COLOR`](https://github.com/mikefarah/yq/blob/master/cmd/root.go) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | no | [`_ZO_DATA_DIR`, `_ZO_ECHO`, `_ZO_EXCLUDE_DIRS`, `_ZO_FZF_OPTS`, `_ZO_MAXAGE`, `_ZO_RESOLVE_SYMLINKS`](https://github.com/ajeetdsouza/zoxide#configuration) |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | no | None; [`ZSH_AUTOSUGGEST_*`](https://github.com/zsh-users/zsh-autosuggestions#configuration) are shell variables |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | no | None; [`ZSH_HIGHLIGHT_*`](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md) are shell variables |

## Zsh startup and ordering

`~/.zshenv` is a regular bootstrap file and the only zsh startup file placed
in `$HOME`. It preserves existing XDG values, fills the standard defaults where
unset, exports `ZDOTDIR="$XDG_CONFIG_HOME/zsh"`, and quietly sources
`$ZDOTDIR/env.zsh`. No `.zshenv` remains inside ZDOTDIR; `.chezmoiremove` migrates
old checkouts away from that former path.

1. `env.zsh`: shared, idempotent environment and PATH setup. `.zshenv` and
   `env.zsh` should **NEVER output anything**: scripts and SSH commands source
   startup files too, so output can corrupt command data or transfer protocols.
   No external commands, prompt hooks or widgets run in these two files.
   XDG config-path overrides, `PAGER=less`, and editor selection live here.
   `EDITOR` and `VISUAL` use nvim when available on the resulting PATH, falling
   back to vim. `XDG_RUNTIME_DIR` remains the OS/session's responsibility.
2. Chezmoi selects the Homebrew prefix when rendering the startup files, using
   the shared `.chezmoitemplates/brew-prefix` template. On macOS, check
   `/opt/homebrew`, then `$HOME/.homebrew`, then `$HOME/.linuxbrew`. On Linux,
   check `/home/linuxbrew/.linuxbrew`, then `$HOME/.linuxbrew`, then
   `$HOME/.homebrew`. Only executable `bin/brew` files count as installations;
   system installs always win. Intel macOS Homebrew under `/usr/local` is not
   supported. `brew shellenv zsh` supplies Homebrew's PATH entries, metadata,
   and completion path; no runtime prefix variable or discovery loop is needed.
   `env.zsh` puts `~/.local/bin` first and retains existing Docker CLI paths
   when present. PATH entries are deduplicated, so repeated sourcing is safe.
   Run `chezmoi apply` after installing or moving Homebrew to render the new
   location. [Chezmoi executable check](https://www.chezmoi.io/reference/templates/functions/isExecutable/).
3. macOS `.zprofile`: after `/etc/zprofile` runs `path_helper`, evaluate
   `brew shellenv zsh` from the selected installation, then source `env.zsh`
   again to restore the shared environment and select the editor with Homebrew
   tools now on PATH. Linux `.zprofile` has no Homebrew
   initialization. [Homebrew shellenv](https://docs.brew.sh/Manpage#shellenv-shell-).
4. `.zshrc`: first source the unmanaged `~/.aliases`, then `~/.functions`, when
   present. On Linux only, next evaluate `brew shellenv zsh`. Interactive shells
   then source `env.zsh` again to support inherited ZDOTDIR and refresh
   editor selection, and initialize history/state/cache directories. Add
   Docker completion paths alongside Homebrew's supplied completions before
   running `compinit` once with its dump under `~/.cache/zsh`. Each `setopt`
   occupies its own line.
5. Set `bindkey -e` for Emacs editing before tool keybindings. Initialize fzf on
   one line with Ctrl-R disabled and its default candidates, then Atuin with
   `--disable-up-arrow`, then zoxide replacing `cd`, then Starship. The default
   aliases/functions section holds shared definitions, including the lazydocker
   scoped-config wrapper. Disable normal/application-mode and terminfo arrow
   sequences after the integrations, keeping Ctrl-F/B/P/N for editing/history.
   Load zsh-autosuggestions and zsh-syntax-highlighting
   with two direct source lines, highlighting last. They use the selected
   Homebrew prefix's `share/<plugin>/` on either OS, or `/usr/share/<plugin>/`
   for standard Linux packages. Install the plugins before starting the shell.
6. `.zlogin` contains only a comment saying it is not used and is tracked as
   a placeholder. `.zlogout` contains `[[ -o interactive ]] && clear` and clears
   the terminal only when an interactive login shell exits.

The shared aliases/functions section contains only the existing lazydocker wrapper.
Use the unmanaged `~/.aliases` and `~/.functions` for per-machine customizations.
Prior aliases were retired to a local backup, including aliases for tools not in
the inventory.

## Interactions and limits

- Atuin and fzf compete for Ctrl-R; Atuin now owns it. fzf retains Ctrl-T/Alt-C,
  also powers zoxide's `cdi`, and uses its default candidate selection. Atuin's Up
  binding is disabled. Arrow keys are disabled at the zsh prompt; Ctrl-F/B moves
  through the line and Ctrl-P/N moves through history. Programs such as Atuin's
  search interface and Neovim use their own keybindings.
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
- lazydocker and lazygit both recognize the generic `CONFIG_DIR`, `DEBUG`, and
  `LOG_LEVEL` variables; gh-dash also uses `LOG_LEVEL`. Scope overrides to the
  command that needs them. The lazydocker shell wrapper scopes `CONFIG_DIR` to
  its XDG config directory without changing lazygit's configuration.
- ripgrep and fd complement LazyVim's search/file pickers; global ignore changes
  affect shell results and integrations. ast-grep is structural search and rewriting,
  using tree-sitter grammars; it does not automatically adopt Neovim's parsers.
  The tree-sitter CLI and Neovim's parser plugins have distinct configs and builds.
- duf reports filesystem free space; dust shows which directories consume space;
  btop monitors processes/resources. Generated caches, parser binaries and other
  tool assets should stay outside chezmoi.
- Installed font/terminal support affects icons, prompt glyphs and theme colors.
  Built-in themes are represented by config choices or application defaults;
  copying every built-in theme is unnecessary. Custom Neovim theme configuration
  and plugin specs under `~/.config/nvim` are tracked; downloaded theme plugins
  remain in Neovim's data directory.
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
LazyVim change or plugin update, run `chezmoi add --secrets error ~/.config/nvim`
to capture the full configuration and updated `lazy-lock.json`. Git metadata is
excluded; newly created config files must be explicitly added. After adding a
custom theme for another managed tool, explicitly add that asset and its
selecting config.
Use `chezmoi update` on other machines to pull and apply the committed config.
The same tool versions may still be needed to reproduce behavior exactly.

## Validation

- Chezmoi init/apply and matching source/destination state on macOS.
- Fresh macOS login/interactive zsh: Atuin owns Ctrl-R; cd/cdi are zoxide functions;
  supported XDG config overrides resolve correctly; lazydocker parses its config.
- Linux target rendered with chezmoi's OS data override, then actual zsh startup
  tested in a disposable Debian-based Docker container with required zsh plugins
  installed and optional CLI tools absent. Confirmed XDG paths, ZDOTDIR,
  state/cache locations, plugin loading and missing-tool guards.
- Interactive login shells run the clear command in `.zlogout`; noninteractive
  login shells leave the terminal alone. `PAGER=less` is available in both.
- The simplified environment was checked with real Homebrew on macOS and both
  OS templates rendered by chezmoi in a Linux container using temporary Homebrew
  fixtures. Verified silent/idempotent sourcing, fresh metadata initialization,
  macOS path_helper recovery, render-time system-before-local selection, both
  local fallbacks, executable checks, paths with spaces, reapplying after moves,
  inherited ZDOTDIR, XDG overrides, and nvim/vim selection. The regular-file
  bootstrap migration was checked when the environment split was introduced.
- bat, eza, dust, ripgrep, Glow, Starship, tree-sitter config loading on macOS;
  superfile v1.6.0 opened successfully with minimal config/hotkeys and exited cleanly.
- JSON/TOML/YAML syntax and Neovim Lua syntax checked before publishing.

Linux validation covers shell startup and target layout, not full interactive
execution of every application or LazyVim language-tool installation on Linux.

The Git identity template was additionally checked with a separate work identity,
including names with spaces, quotes and backslashes, and repeated initialization
was checked to preserve the saved machine-local identity without prompting.

The full LazyVim configuration and plugin lockfile are tracked with ordinary
source attributes. macOS and Linux target layouts and the comment-only `.zlogin`
were checked after updating the tracking scope.
Fresh init/apply/verify checks for both OS targets also restored `~/.editorconfig`,
preserved existing unmanaged aliases/functions, and confirmed their startup order
and optional loading when absent. Neovim's EditorConfig parser confirmed the home
defaults and a closer project's override.

The Starship directory migration, Emacs keymap, disabled arrows, preserved
Ctrl-F/B/P/N and Atuin Ctrl-R, and superfile visibility preference were checked
with fresh macOS/Linux template targets. Superfile v1.6.0 displayed a hidden
fixture file on startup, and Neovim saved its preference without adding a newline.
