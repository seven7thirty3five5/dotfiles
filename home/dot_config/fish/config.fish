# ~/.config/fish/config.fish: fish reads this after every file in conf.d. Those
# set up the environment for every fish; this file sets up the shells you type
# into: colors, abbreviations and the tools that hook into the prompt. Functions
# such as update and doctor live in ~/.config/fish/functions, one per file, and
# fish loads each one the first time you use it.
#
# How to read this file:
#   if status is-interactive   true in a shell you type into. herdr's popups
#                              and scripts skip this whole block, which keeps
#                              them fast and silent.
#   command -q eza             "is eza installed?" Settings for optional tools
#                              are skipped when the tool is missing.
#   abbr --add l 'eza ...'     typing l and then a space or Enter expands it to
#                              the full command, which you see before it runs
#                              and which history saves in full.
#   tool init fish | source    runs the setup code a tool prints for fish.

if status is-interactive
    # No "Welcome to fish" greeting when a shell starts.
    set -g fish_greeting

    # Colors: Catppuccin Mocha, one of the themes built into fish (see them
    # with `fish_config theme show`). Its dark variant always, even if the
    # terminal reports a light background. Suggestions then use Catppuccin's
    # Overlay1 instead of the theme's dimmer Overlay0.
    fish_config theme choose catppuccin-mocha --color-theme=dark
    set -g fish_color_autosuggestion 7f849c

    # Abbreviations, only for programs that are installed. --description is
    # what Tab's list of completions shows next to the name.

    # Open Micro, the default terminal text editor.
    if command -q micro
        abbr --add ww --description 'Open Micro' micro
    end

    # eza listings; plain ls keeps its usual flags (ls -ltr etc.). Folders
    # first, icons, and a Git status column in the long views.
    if command -q eza
        abbr --add l --description 'List all files in detail' \
            eza -lah --group-directories-first --icons=auto --git
        abbr --add ll --description 'List visible files in detail' \
            eza -l --group-directories-first --icons=auto --git
        abbr --add la --description 'List files in detail, hidden ones too' \
            eza -la --group-directories-first --icons=auto --git
        abbr --add lt --description 'Show a folder tree two levels deep' \
            eza --tree --level=2 --group-directories-first --icons=auto
        abbr --add lr --description 'Show the Git status of each repository' \
            eza -l --git-repos --group-directories-first --icons=auto
    end

    if command -q bat
        abbr --add bathelp --description 'Highlight piped help text' \
            bat --plain --language=help
        abbr --add bcat --description 'Print a highlighted file, no pager' \
            bat --plain --paging=never
    end

    if command -q fd
        abbr --add fdall --description 'Find hidden and ignored files too' \
            fd --hidden --no-ignore --exclude .git
    end

    if command -q rg
        abbr --add rgall --description 'Search ignored files too' \
            rg --no-ignore
    end

    if command -q duf
        abbr --add dfh --description 'Show usage of local disks' \
            duf --only local
    end

    if command -q dust
        abbr --add du2 --description 'Show folder sizes two levels deep' \
            dust --depth 2
    end

    if command -q hyperfine
        abbr --add bench --description 'Benchmark after three warm-up runs' \
            hyperfine --warmup 3
    end

    if command -q yq
        abbr --add y2j --description 'Convert YAML to JSON' \
            yq -o=json
        abbr --add j2y --description 'Convert JSON to YAML' \
            yq -p=json -o=yaml -P
    end

    # .. goes up one folder, ... two, .... three, and so on: typing two or
    # more dots expands to `cd ../`, `cd ../../` and so on. --regex matches the
    # whole word against a pattern (two or more dots), and --function asks
    # _multicd (in functions/) for the expansion. From fish's documentation.
    abbr --add dotdot --regex '^\.\.+$' --function _multicd

    # fzf: Ctrl-T picks files and Alt-C changes to a folder, both listed by fd
    # so that fzf respects .gitignore (fzf README, "Respecting .gitignore").
    # Ctrl-T previews files with bat (Ctrl-/ moves or hides the preview), and
    # Ctrl-O there opens the selected files in Micro. Alt-C previews folders
    # as trees with eza. Inside double quotes, a backslash at the end of a line
    # continues the text on the next line.
    if command -q fzf
        if command -q fd
            set -gx FZF_DEFAULT_COMMAND 'fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
            set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
            set -gx FZF_ALT_C_COMMAND 'fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
        end

        if command -q bat
            set -gx FZF_CTRL_T_OPTS "--walker-skip .git,node_modules,target \
                --preview 'bat -n --color=always {}' \
                --bind 'ctrl-/:change-preview-window(down|hidden|)'"
        end

        if command -q micro
            set -gx FZF_CTRL_T_OPTS "$FZF_CTRL_T_OPTS --bind 'ctrl-o:execute(micro -- {+})'"
        end

        if command -q eza
            set -gx FZF_ALT_C_OPTS "--walker-skip .git,node_modules,target \
                --preview 'eza --tree --level=2 --color=always {} | head -200'"
        end

        # Atuin owns Ctrl-R: an empty FZF_CTRL_R_COMMAND tells fzf not to bind
        # it. Then load fzf's key bindings, plus its completion on Shift-Tab
        # (fzf's version of zsh's **<Tab>).
        set -g FZF_CTRL_R_COMMAND ''
        fzf --fish | source
    end

    # Start the tools that hook into the shell:
    #   mise      selects the runtimes for this folder, and updates them when
    #             you cd.
    #   atuin     searchable history on Ctrl-R, loaded after fzf so it wins
    #             that key. --disable-up-arrow leaves Up to fish's history
    #             search, and --disable-ai leaves ? alone instead of binding it
    #             to Atuin AI.
    #   zoxide    --cmd cd makes cd smarter: cd with part of a folder's name
    #             jumps to the matching folder you use most.
    #   starship  draws the prompt.
    command -q mise; and mise activate fish | source
    command -q atuin; and atuin init fish --disable-up-arrow --disable-ai | source
    command -q zoxide; and zoxide init fish --cmd cd | source
    command -q starship; and starship init fish | source
end

# Machine-specific settings, not tracked by chezmoi: put them in
# ~/.config/fish/config-local.fish. Lines that installers (Docker Desktop,
# conda, nvm and so on) offer to add to config.fish belong there too. It loads
# last, in every fish, so it can override everything above; wrap settings that
# only make sense when typing in `if status is-interactive ... end`. (status
# dirname is the folder this file is in.)
set -l local_config (status dirname)/config-local.fish
test -f $local_config; and source $local_config
