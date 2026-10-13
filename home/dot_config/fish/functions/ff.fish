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
    # file into cwd.
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    command yazi $argv --cwd-file=$tmp
    if read -z cwd <$tmp; and test "$cwd" != "$PWD"; and test -d "$cwd"
        # Yazi's own wrapper uses `builtin cd`, which skips fish's cd function,
        # the part that records directory history, so `cd -`, Alt-Left and cdh
        # would go to the wrong place afterwards. zoxide's cd accepts -- and
        # hands off to fish's cd.
        cd -- $cwd
    end

    command rm -f -- $tmp
end
