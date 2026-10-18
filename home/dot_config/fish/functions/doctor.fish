# Every check runs even after one fails: brew doctor fails on mere warnings.
function doctor --description 'Check Homebrew, chezmoi, mise and authorization'
    argparse --name=doctor --max-args=0 h/help -- $argv
    or return

    if set -q _flag_help
        echo 'Usage: doctor'
        echo 'Runs brew doctor, chezmoi doctor and mise doctor, then checks'
        echo 'authorization for Claude Code, Codex and GitHub.'
        echo 'Also reports optional Docker Hub sign-in status.'
        echo 'Continues after failures.'
        return 0
    end

    set -l failed 0

    _dotfiles_section Homebrew cyan
    brew doctor; or set failed 1

    _dotfiles_section chezmoi yellow
    chezmoi doctor; or set failed 1

    _dotfiles_section mise magenta
    mise doctor; or set failed 1

    _dotfiles_section Authorization blue
    set -lx GH_PROMPT_DISABLED 1

    _dotfiles_subsection claude blue
    claude auth status --text; or set failed 1

    _dotfiles_subsection codex blue
    codex login status; or set failed 1

    _dotfiles_subsection gh blue
    gh auth status; or set failed 1

    # Docker Desktop's auth command is only available on supported installs.
    # Its optional sign-in status doesn't affect the health-check result.
    if command -q docker; and docker desktop auth status --help >/dev/null 2>&1
        _dotfiles_subsection 'Docker Hub (optional)' blue
        docker desktop auth status
    end

    return $failed
end
