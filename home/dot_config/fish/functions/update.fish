# Each step's comments explain it; the first step that fails stops the update.
function update --description 'Update chezmoi, Homebrew, mise and what they install'
    argparse --name=update --max-args=0 h/help -- $argv
    or return

    if set -q _flag_help
        echo 'Usage: update'
        echo 'Updates chezmoi, the dotfiles, Homebrew and its packages, mise and'
        echo 'its runtimes, the global agent skills, gh extensions and the herdr'
        echo 'integrations, accepting every confirmation.'
        echo 'Stops at the first step that fails.'
        return 0
    end

    # Check every tool first, so a missing one doesn't stop the update halfway.
    for tool in chezmoi brew mise pnpm gh herdr
        if not command -q $tool
            echo "update: $tool is not installed" >&2
            return 1
        end
    end

    # Never stop to ask: accept Homebrew's and mise's questions, here and in
    # chezmoi's scripts, and turn off gh's prompts.
    set -lx HOMEBREW_NO_ASK 1
    set -lx MISE_YES 1
    set -lx GH_PROMPT_DISABLED 1

    # chezmoi first, so the Brewfile, mise config and skills script it applies
    # (and installs from) are current before the rest updates them.
    _dotfiles_section chezmoi yellow
    _dotfiles_subsection 'Upgrade chezmoi' yellow
    chezmoi upgrade; or return

    # --force replaces locally changed files without asking; --no-tty never prompts.
    _dotfiles_subsection 'Pull and apply dotfiles' yellow
    chezmoi update --force --no-tty; or return

    _dotfiles_section Homebrew cyan
    _dotfiles_subsection 'Refresh package lists' cyan
    brew update; or return
    # brew upgrade skips casks marked as updating themselves, and they do.
    # If you turn one's updater off, have Homebrew upgrade it anyway with
    # `set -lx HOMEBREW_UPGRADE_GREEDY_CASKS <cask>...` here. Not --greedy for
    # all: Logi Options+ would run its installer with sudo, asking for a password.
    _dotfiles_subsection 'Upgrade packages' cyan
    brew upgrade --no-ask; or return

    _dotfiles_section mise magenta
    _dotfiles_subsection 'Upgrade mise' magenta
    mise self-update --yes; or return
    _dotfiles_subsection 'Upgrade runtimes' magenta
    mise upgrade --yes; or return

    # The skills installed with -g (see the install-skills chezmoi script).
    # --dir runs pnpm from home, so a project's pnpm settings don't apply.
    _dotfiles_section 'Agent skills' red
    _dotfiles_subsection 'Update global skills' red
    pnpm --dir $HOME dlx skills update --global --yes; or return

    # gh's extensions, such as gh-dash, are installed by gh, not Homebrew.
    _dotfiles_section 'gh extensions' blue
    _dotfiles_subsection 'Upgrade extensions' blue
    gh extension upgrade --all; or return

    # herdr's hooks for Claude Code and Codex. herdr owns these files, so the
    # dotfiles don't track them; this installs them, and installing again
    # replaces them with this herdr's version. herdr only installs into an
    # agent's config folder that exists, and each agent creates its own when it
    # first runs, so create them first: $CLAUDE_CONFIG_DIR and $CODEX_HOME when
    # set (herdr reads them too), otherwise ~/.claude and ~/.codex.
    _dotfiles_section 'herdr integrations' green
    set -l agent_dirs $HOME/.claude $HOME/.codex
    test -n "$CLAUDE_CONFIG_DIR"; and set agent_dirs[1] $CLAUDE_CONFIG_DIR
    test -n "$CODEX_HOME"; and set agent_dirs[2] $CODEX_HOME
    mkdir -p $agent_dirs; or return
    _dotfiles_subsection 'Update Claude integration' green
    herdr integration install claude; or return
    _dotfiles_subsection 'Update Codex integration' green
    herdr integration install codex; or return

    # More tools with their own plugins or packages, off until you use them:
    # uncomment a section to update its tool too.

    # Claude Code plugins. Claude refreshes its official marketplace itself;
    # this refreshes every marketplace, then updates each plugin installed for
    # your user. A plugin update that runs a marketplace's own command still
    # asks first; -y would accept such commands without showing them to you.
    # _dotfiles_section 'Claude Code plugins' bryellow
    # _dotfiles_subsection 'Refresh marketplaces' bryellow
    # claude plugin marketplace update; or return
    # for plugin in (claude plugin list --json | jq -r '.[] | select(.scope == "user") | .id')
    #     _dotfiles_subsection "Update $(string split -f1 @ $plugin)" bryellow
    #     claude plugin update --scope user $plugin; or return
    # end

    # Codex plugins. Its bundled plugins update with the codex cask; this
    # refreshes marketplaces added with `codex plugin marketplace add`.
    # _dotfiles_section 'Codex plugins' white
    # _dotfiles_subsection 'Refresh marketplaces' white
    # codex plugin marketplace upgrade; or return

    # Pythons that uv downloads itself for projects; mise upgrades its own.
    # _dotfiles_section 'uv Pythons' brmagenta
    # _dotfiles_subsection 'Upgrade Pythons' brmagenta
    # uv python upgrade; or return

    # yazi's plugins and flavors added with `ya pkg add`.
    # _dotfiles_section 'yazi packages' brcyan
    # _dotfiles_subsection 'Upgrade packages' brcyan
    # ya pkg upgrade; or return

    # micro's plugins added with `micro -plugin install`.
    # _dotfiles_section 'micro plugins' brgreen
    # _dotfiles_subsection 'Update plugins' brgreen
    # micro -plugin update; or return

    # bat's custom themes and syntaxes (~/.config/bat/themes and syntaxes),
    # which bat only reads from its cache.
    # _dotfiles_section 'bat themes' brblue
    # _dotfiles_subsection 'Rebuild theme cache' brblue
    # bat cache --build; or return

    # Globally installed npm packages. mise's Node keeps npm's; a new Node
    # version starts without them. --dir runs pnpm from home, as above.
    # _dotfiles_section 'Global npm packages' brred
    # _dotfiles_subsection 'Update pnpm packages' brred
    # pnpm --dir $HOME update --global; or return
    # _dotfiles_subsection 'Update npm packages' brred
    # npm update --global; or return

    # Docker Desktop's extensions (turn them on in Docker Desktop first).
    # --force reinstalls each without asking.
    # _dotfiles_section 'Docker extensions' brwhite
    # for extension in (docker extension ls --quiet)
    #     _dotfiles_subsection "Update $extension" brwhite
    #     docker extension update --force $extension; or return
    # end

    # Fresh's packages (themes, plugins and languages) can only be updated
    # from inside the editor; it has no command for this.
end
