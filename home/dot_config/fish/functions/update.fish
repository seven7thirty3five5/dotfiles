# update: update everything these dotfiles install, in three parts with a
# heading each: Homebrew (and gh's extensions), chezmoi, and mise. It stops at
# the first step that fails. The README lists the steps and explains them.
function update --description 'Update Homebrew, chezmoi, mise and what they install'
    # argparse reads the options: -h or --help sets _flag_help, and
    # --max-args=0 rejects any other words. `or return` stops if it complains.
    argparse --name=update --max-args=0 h/help -- $argv
    or return

    if set -q _flag_help
        echo 'Usage: update'
        echo 'Updates Homebrew and its packages, gh extensions, chezmoi, the'
        echo 'dotfiles, mise and its runtimes, accepting every confirmation.'
        echo 'Stops at the first step that fails.'
        return 0
    end

    # Check for every program first, so a missing one doesn't stop it halfway.
    for tool in brew gh chezmoi mise
        if not command -q $tool
            echo "update: $tool is not installed" >&2
            return 1
        end
    end

    # Export these only while this function runs, including to the setup
    # scripts chezmoi runs: Homebrew and mise accept their confirmation
    # questions (-l: local to this function, -x: exported).
    set -lx HOMEBREW_NO_ASK 1
    set -lx MISE_YES 1

    _dotfiles_section Homebrew cyan

    # Refresh Homebrew's package list, then upgrade its outdated packages.
    # --no-ask accepts the upgrade; apps that update themselves stay excluded.
    # `or return` stops the update with that step's error status.
    brew update; or return
    brew upgrade --no-ask; or return

    # gh is a Homebrew shell tool; update its extensions, such as gh-dash, here.
    gh extension upgrade --all; or return

    _dotfiles_section chezmoi yellow

    # Upgrade chezmoi itself. Refresh mise before applying the dotfiles so its
    # generated completion matches the updated program. --force accepts file
    # replacements and --no-tty keeps chezmoi from opening a prompt.
    chezmoi upgrade; or return
    mise self-update --yes; or return
    chezmoi update --force --no-tty; or return

    _dotfiles_section mise magenta

    # Upgrade the configured runtimes without asking; mise later prunes the
    # versions they replace by itself.
    mise upgrade --yes
end
