# help COMMAND: show a command's --help output with colors (from bat's README),
# for example `help git commit`. This replaces fish's own help command, which
# opens fish's documentation in a browser; `man fish` still shows that.
function help --description "Show a command's --help with colors, e.g. help git commit"
    if not command -q bat
        echo 'help: bat is not installed' >&2
        return 1
    end

    # (count $argv) is how many words follow help.
    if test (count $argv) -eq 0
        echo 'Usage: help COMMAND [SUBCOMMAND...]' >&2
        return 2
    end

    # Run the words as a command with --help added. 2>&1 includes error
    # output, where some programs print their help.
    $argv --help 2>&1 | bat --plain --language=help
end
