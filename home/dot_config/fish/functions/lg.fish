# lazygit's change-directory-on-exit wrapper from its README, named lg: when you
# switch repositories in lazygit and quit with q, cd to the one it was in.
# Shift-Q quits back to the folder you started in.
function lg --description 'Open lazygit, then cd to the repository it was in'
    if not command -q lazygit
        echo 'lg: lazygit is not installed' >&2
        return 1
    end

    # As it quits, lazygit writes its folder to the file LAZYGIT_NEW_DIR_FILE
    # names: here a new temporary file each time, as ff does for Yazi, rather
    # than the README's fixed ~/.lazygit/newdir.
    set tmp (mktemp -t "lazygit-dir.XXXXXX")
    LAZYGIT_NEW_DIR_FILE=$tmp command lazygit $argv

    # Move only to a different folder that still exists. read -z reads the whole
    # file (lazygit writes no newline); builtin cd is fish's own cd, not zoxide's.
    if read -z dir <"$tmp"; and [ "$dir" != "$PWD" ]; and test -d "$dir"
        builtin cd -- "$dir"
    end
    command rm -f -- "$tmp"
end
