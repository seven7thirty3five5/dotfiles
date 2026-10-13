# Interactive setup; conf.d sets the environment for every fish, popups included.

if status is-interactive
    # No greeting, so startup prints nothing.
    set -g fish_greeting

    # Catppuccin Mocha, built into fish; always its dark variant.
    fish_config theme choose catppuccin-mocha --color-theme=dark

    # Catppuccin's Overlay1: the theme's own suggestion color is too dim.
    set -g fish_color_autosuggestion 7f849c

    # Abbreviations. --description needs the =: with a space, fish 4.9.3 makes
    # the text part of the expansion.
    abbr --add ww --description='Open Micro' micro

    # eza views that fish has no equivalent for; ll and la are fish's own.
    abbr --add lt --description='Show a folder tree two levels deep' \
        eza --tree --level=2 --group-directories-first --icons=auto
    abbr --add lr --description='Show the Git status of each repository' \
        eza -l --git-repos --group-directories-first --icons=auto

    abbr --add bcat --description='Print a highlighted file, no pager' \
        bat --plain --paging=never
    abbr --add fdall --description='Find hidden and ignored files too' \
        fd --hidden --no-ignore --exclude .git
    abbr --add rgall --description='Search ignored files too' \
        rg --no-ignore
    abbr --add dfh --description='Show usage of local disks' \
        duf --only local
    abbr --add du2 --description='Show folder sizes two levels deep' \
        dust --depth 2
    abbr --add bench --description='Benchmark after three warm-up runs' \
        hyperfine --warmup 3
    abbr --add y2j --description='Convert YAML to JSON' \
        yq -o=json
    abbr --add j2y --description='Convert JSON to YAML' \
        yq -p=json -o=yaml -P

    # .., ..., .... expand to cd ../, cd ../../ and so on (fish's documentation).
    abbr --add dotdot --regex '^\.\.+$' --function _multicd

    # fzf's key bindings are off: atuin covers Ctrl-R and yazi covers browsing.
    # You may want fzf's file picker on Ctrl-T later. `fzf --fish | source` turns
    # on Ctrl-T, Alt-C, Ctrl-R and Shift-Tab at once, and a custom
    # FZF_CTRL_T_COMMAND must use $dir to search inside a typed path (fzf README).

    # mise switches runtimes when you cd.
    command -q mise; and mise activate fish | source

    # atuin on Ctrl-R; Up stays fish's own, and ? isn't bound to Atuin AI.
    command -q atuin; and atuin init fish --disable-up-arrow --disable-ai | source

    # zoxide's cd also jumps to frequently used folders by part of their name.
    command -q zoxide; and zoxide init fish --cmd cd | source

    # starship draws the prompt.
    command -q starship; and starship init fish | source
end

# Untracked per-machine settings, loaded last in every fish.
set -l local_config (status dirname)/config-local.fish
test -f $local_config; and source $local_config
