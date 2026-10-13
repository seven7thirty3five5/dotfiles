# Plain text when the output isn't a terminal or NO_COLOR is set, for readable logs.
function _dotfiles_section --argument-names name color --description 'Print a heading for update and doctor'
    if isatty stdout; and test -z "$NO_COLOR"
        printf '\n'
        set_color --bold $color
        printf '== %s ==' $name
        set_color normal
        printf '\n'
    else
        printf '\n== %s ==\n' $name
    end
end
