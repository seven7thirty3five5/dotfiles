# Plain text when the output isn't a terminal or NO_COLOR is set, for readable logs.
# Not bold, with an arrow and no blank line before it, to sit under its section.
function _dotfiles_subsection --argument-names name color --description 'Print a subheading for update and doctor'
    if isatty stdout; and test -z "$NO_COLOR"
        set_color $color
        printf '-> %s' $name
        set_color normal
        printf '\n'
    else
        printf '-> %s\n' $name
    end
end
