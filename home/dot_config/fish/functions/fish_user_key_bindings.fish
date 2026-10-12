# fish runs fish_user_key_bindings by itself, once, before the first prompt,
# after setting up its own key bindings; `bind` here adds to or replaces them.
# Everything else stays fish's default Emacs-style editing (Ctrl-A, Ctrl-E,
# Alt-arrows and so on; `bind` lists them all), including Alt-E, which opens
# the command line in your editor.
function fish_user_key_bindings --description 'Key bindings added to the fish defaults'
    # Up/Down (and Ctrl-P/Ctrl-N) only find earlier commands that START with
    # what you've typed. fish's default finds commands that contain it
    # anywhere. With an empty command line, both step through all of history.
    bind up history-prefix-search-backward
    bind down history-prefix-search-forward
    bind ctrl-p history-prefix-search-backward
    bind ctrl-n history-prefix-search-forward
end
