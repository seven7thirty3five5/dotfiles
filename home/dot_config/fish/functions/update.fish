# The README explains each step; the first one that fails stops the update.
function update --description 'Update Homebrew, chezmoi, mise and what they install'
    argparse --name=update --max-args=0 h/help -- $argv
    or return

    if set -q _flag_help
        echo 'Usage: update'
        echo 'Updates Homebrew and its packages, gh extensions, chezmoi, the'
        echo 'dotfiles, mise and its runtimes, accepting every confirmation.'
        echo 'Stops at the first step that fails.'
        return 0
    end

    # Check every tool first, so a missing one doesn't stop the update halfway.
    for tool in brew gh chezmoi mise
        if not command -q $tool
            echo "update: $tool is not installed" >&2
            return 1
        end
    end

    # Accept Homebrew's and mise's questions, here and in chezmoi's scripts.
    set -lx HOMEBREW_NO_ASK 1
    set -lx MISE_YES 1

    _dotfiles_section Homebrew cyan
    brew update; or return
    brew upgrade --no-ask; or return

    # gh's extensions, such as gh-dash, update with the Homebrew tools.
    gh extension upgrade --all; or return

    _dotfiles_section chezmoi yellow
    chezmoi upgrade; or return

    # --force replaces locally changed files without asking; --no-tty never prompts.
    chezmoi update --force --no-tty; or return

    _dotfiles_section mise magenta
    mise self-update --yes; or return
    mise upgrade --yes
end
