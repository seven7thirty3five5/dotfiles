# Yazi's quick-start wrapper, named ff: after you quit Yazi, cd to its folder.
function ff --description 'Open Yazi, then cd to the folder it was in'
    if not command -q yazi
        echo 'ff: yazi is not installed' >&2
        return 1
    end

    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    command yazi $argv --cwd-file=$tmp
    if read -z cwd <$tmp; and test "$cwd" != "$PWD"; and test -d "$cwd"
        # cd, not Yazi's `builtin cd`: fish's cd function records directory
        # history (cd -, Alt-Left, cdh), and zoxide's cd hands -- on to it.
        cd -- $cwd
    end

    command rm -f -- $tmp
end
