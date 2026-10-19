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

    # Check the standalone tools first. mise selects global Node and pnpm later,
    # so a project's missing or pinned package manager cannot block the update.
    for tool in chezmoi brew mise gh herdr
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
    # --global selects the machine's requests even inside a project that pins
    # different versions, without reading or changing its config or lockfile.
    mise upgrade --global --yes; or return

    # The skills installed with -g (see the install-skills chezmoi script).
    # mise exec --cd selects the global Node and pnpm from home, rather than
    # whichever versions the calling project put on PATH. pnpm's --dir also
    # keeps that project's package settings out of the skills update.
    _dotfiles_section 'Agent skills' red
    _dotfiles_subsection 'Update global skills' red
    mise exec --cd $HOME -- pnpm --dir $HOME dlx skills update --global --yes; or return

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
end
