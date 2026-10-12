# doctor: check all three managers, with the same headings as update. Every
# check runs, even after one reports a problem: brew doctor reports even
# warnings as a failure, which would otherwise skip the other two.
function doctor --description 'Check Homebrew, chezmoi and mise for problems'
    argparse --name=doctor --max-args=0 h/help -- $argv
    or return

    if set -q _flag_help
        echo 'Usage: doctor'
        echo 'Runs brew doctor, chezmoi doctor and mise doctor, each in turn.'
        return 0
    end

    for tool in brew chezmoi mise
        if not command -q $tool
            echo "doctor: $tool is not installed" >&2
            return 1
        end
    end

    _dotfiles_section Homebrew cyan
    brew doctor

    _dotfiles_section chezmoi yellow
    chezmoi doctor

    _dotfiles_section mise magenta
    mise doctor
end
