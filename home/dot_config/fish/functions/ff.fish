# ff: open Yazi, the file manager, and when you quit it, change this shell to
# the folder Yazi was in. Yazi writes that folder into a temporary file
# (--cwd-file); this function reads it, moves there and removes the file. This
# is the fish wrapper from Yazi's quick-start guide, named ff.
function ff --description 'Open Yazi, then cd to the folder it was in'
    if not command -q yazi
        echo 'ff: yazi is not installed' >&2
        return 1
    end

    # mktemp makes an empty temporary file and prints its name. $argv is
    # everything typed after ff, passed on to yazi. read -z reads the whole
    # file into cwd; builtin cd skips the cd wrapper that zoxide adds.
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    command yazi $argv --cwd-file=$tmp
    if read -z cwd <$tmp; and test "$cwd" != "$PWD"; and test -d "$cwd"
        builtin cd -- $cwd
    end

    command rm -f -- $tmp
end
