# Interactive setup; conf.d sets the environment for every fish, popups included.

if status is-interactive
    # No greeting, so startup prints nothing.
    set -g fish_greeting

    # Catppuccin Mocha, built into fish; always its dark variant.
    fish_config theme choose catppuccin-mocha --color-theme=dark

    # Catppuccin's Overlay1: the theme's own suggestion color is too dim.
    set -g fish_color_autosuggestion 7f849c

    # Abbreviations: type one and press space or enter, and fish replaces it
    # with the full command, so history shows what really ran.

    # Terminal interfaces get a doubled letter, like ff for Yazi and gg (a
    # function) for lazygit. dd hides the system's dd (disk copy) when typed;
    # scripts still get it, and `command dd` runs it by hand.
    abbr --add dd lazydocker
    abbr --add hh gh dash

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
