# Yazi's quick-start wrapper, named ff: after you quit Yazi, cd to its folder.
function ff --description 'Open Yazi, then cd to the folder it was in'
    if not command -q yazi
        echo 'ff: yazi is not installed' >&2
        return 1
    end

    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"
    if read -z cwd <"$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
        builtin cd -- "$cwd"
    end
    command rm -f -- "$tmp"
end
