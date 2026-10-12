# _dotfiles_section NAME COLOR: print a heading before each manager's output in
# update and doctor, such as "== Homebrew ==". In a terminal it's bold and
# colored. When the output goes to a file or another program, or when NO_COLOR
# is set to anything, it's plain text, which keeps logs readable.
function _dotfiles_section --argument-names name color --description 'Print a heading for update and doctor'
    # isatty stdout: the output goes to a terminal. test -z: NO_COLOR is empty
    # or unset. set_color changes the color of what's printed next, and
    # set_color normal changes it back.
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
