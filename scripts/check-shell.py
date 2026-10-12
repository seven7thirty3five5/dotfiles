#!/usr/bin/env python3
"""Check that the shell startup files work, without touching your real home folder.

What this tests
---------------
herdr's panes run fish, and fish reads the same files every time it starts:
first everything in ~/.config/fish/conf.d (in name order), then
~/.config/fish/config.fish. What differs is what those files do with it:

  - every fish, even one that just runs a command (as herdr's popups do with
    `fish -c lazygit`), gets the environment: XDG folders, Homebrew, PATH with
    ~/.local/bin first, and the editor;
  - an "interactive" fish (one you type into) also gets the colors,
    abbreviations and key bindings;
  - a "login" fish (herdr's panes on macOS) first runs fish's copy of macOS's
    path_helper, which puts the system's folders at the front of PATH; the
    dotfiles must move ~/.local/bin and Homebrew back in front.

The login shells only start herdr, and their one startup file only adds
Homebrew: ~/.zprofile for zsh on macOS, ~/.bashrc for bash on Linux.

This script checks all of that by:

  1. asking chezmoi to produce ("render") the files from their templates, and
     checking that fish can read them without syntax errors (fish --no-execute)
     and that they are formatted the way fish_indent formats them;
  2. starting fish in all four combinations of login or not and interactive or
     not, once with a pretend Homebrew and once without, and running a small
     fish script (PROBE, below) that checks the environment;
  3. starting this system's login shell the same ways, to check that only the
     ones you type into (or log in with) get Homebrew.

Everything happens inside a temporary folder that is deleted afterwards, with a
made-up home folder, so your real dotfiles and settings are never read or changed.

Run it with:  python3 scripts/check-shell.py
It prints a PASS line for each check, or FAIL with the reason (exit status 1).
GitHub runs it on macOS and Linux for every push (.github/workflows/shell-checks.yml).
"""

# Python's standard library only, so there is nothing to install.
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


# The repository folder. This file is scripts/check-shell.py, so the repository
# is its parent's parent; .resolve() turns the path into a full, absolute one.
SOURCE = Path(__file__).resolve().parents[1]

# The dotfiles live in the subdirectory named by .chezmoiroot (home/).
STATE_NAME = (SOURCE / ".chezmoiroot").read_text().strip()

# fish's folder inside a home folder, and this system's login-shell file.
FISH_DIR = Path(".config/fish")
LOGIN_FILE = Path(".zprofile" if sys.platform == "darwin" else ".bashrc")

# Templates whose text comes from a program (Homebrew, mise, chezmoi itself)
# rather than from this repository. Their syntax is checked, but not their
# formatting: fish_indent would format the programs' output differently, and
# that output isn't ours to change.
GENERATED = ("output ", 'completion "fish"')

# Optional tools that must not be found while the startup files are tested;
# finding one would mean the test is using programs that happen to be installed
# on this computer.
OPTIONAL_TOOLS = "yazi eza fzf atuin zoxide starship lazydocker mise bat fd"

# PROBE is a small fish script that runs right after fish has read the startup
# files. Each line checks one thing; if it's wrong, fail prints a message as an
# error and stops with exit status 1. The checks:
#
#   XDG_*_HOME == the usual folders   The XDG folders (where programs keep config,
#                                     data, state and cache files) are set.
#   $PATH[1] == ~/.local/bin          Your own programs in ~/.local/bin come first
#                                     on PATH, before Homebrew's and the system's.
#   DOTFILES_TEST_BREW_LOADED         The pretend Homebrew sets this when it's
#     == DOTFILES_EXPECT_BREW         loaded: in every fish when it exists.
#   EDITOR and VISUAL match expected  micro when Homebrew provides it, otherwise vi.
#   micro and fresh match Homebrew    Both editor stand-ins are found only through
#                                     Homebrew's PATH.
#   optional tools are not found      See OPTIONAL_TOOLS above.
#   (macOS login shells instead)      path_helper adds the system's folders from
#                                     /etc/paths and /etc/paths.d, where Homebrew's
#                                     installer lists the real Homebrew. There, the
#                                     three checks above can't hold; instead the
#                                     pretend Homebrew must come before /usr/bin.
#   interactive settings              The theme, abbreviations and key bindings
#                                     exist in interactive shells, and the
#                                     abbreviations don't in the others.
#
# Finally it prints "dotfiles-shell-ok". That must be the only output: anything
# else the startup files print would be a bug (see run() below).
#
# The r"""...""" form is a "raw" multi-line string: Python keeps the backslashes
# and quotes inside it exactly as written.
PROBE = r"""
function fail
    echo $argv >&2
    exit 1
end
test "$XDG_CONFIG_HOME" = "$HOME/.config"; or fail 'Unexpected config directory'
test "$XDG_DATA_HOME" = "$HOME/.local/share"; or fail 'Unexpected data directory'
test "$XDG_STATE_HOME" = "$HOME/.local/state"; or fail 'Unexpected state directory'
test "$XDG_CACHE_HOME" = "$HOME/.cache"; or fail 'Unexpected cache directory'
test "$PATH[1]" = "$HOME/.local/bin"; or fail "~/.local/bin lost PATH priority: $PATH"
set -l loaded 0
set -q DOTFILES_TEST_BREW_LOADED; and set loaded 1
test $loaded = $DOTFILES_EXPECT_BREW; or fail 'Homebrew initialized in the wrong shell mode'
if test $DOTFILES_SYSTEM_PATHS = 0
    test "$EDITOR" = "$DOTFILES_EXPECT_EDITOR" -a "$VISUAL" = "$EDITOR"; or fail "Unexpected editor: $EDITOR"
    for editor in micro fresh
        set -l found 0
        command -q $editor; and set found 1
        test $found = $DOTFILES_EXPECT_BREW; or fail "Editor unexpectedly available or missing: $editor"
    end
    for tool in (string split ' ' -- $DOTFILES_OPTIONAL_TOOLS)
        not command -q $tool; or fail "Optional tool unexpectedly available: $tool"
    end
else
    set -l system (contains --index -- /usr/bin $PATH); or fail 'path_helper did not run'
    if test $DOTFILES_EXPECT_BREW = 1
        set -l brew (contains --index -- $DOTFILES_MOCK_BIN $PATH)
        test "$brew" -lt $system; or fail "Homebrew is behind the system's folders: $PATH"
    end
end
if status is-interactive
    test "$fish_color_autosuggestion" = 7f849c; or fail 'The color theme was not applied'
    abbr -q dotdot; or fail 'Abbreviations were not set up'
    if test "$EDITOR" = micro
        abbr --show | string match -q -- '* -- ww micro'; or fail 'ww does not expand to micro'
    end
    for name in update doctor help ff
        functions -q $name; or fail "Function missing: $name"
    end
    fish_user_key_bindings
    bind up | string match -q '*history-prefix-search-backward*'; or fail 'Up is not a prefix search'
else
    not abbr -q dotdot; or fail 'Abbreviations leaked into a non-interactive shell'
end
echo dotfiles-shell-ok
"""

# bash prints these two lines when it starts interactively without a terminal,
# as it does here. They come from bash itself, not from the startup files, so
# run() ignores them (each line starts with "bash: ").
BASH_NO_TERMINAL = ("cannot set terminal process group", "no job control in this shell")


def run(command, env, cwd):
    """Run a command and return what it printed.

    Raise an error if the command fails, and also if it prints anything at all as
    an error message (to stderr). That strictness is deliberate: startup files
    must be completely silent, because anything they print can break programs
    that talk to another computer over SSH, such as scp, rsync and git. So even
    a harmless-looking warning counts as a failure.

    timeout=30 stops a command that hangs, for example one waiting for input,
    and stdin=DEVNULL gives it nothing to read.
    """

    result = subprocess.run(
        command, env=env, cwd=cwd, text=True, capture_output=True, timeout=30,
        stdin=subprocess.DEVNULL,
    )
    stderr = "".join(
        line for line in result.stderr.splitlines(keepends=True)
        if not (line.startswith("bash: ")
                and any(message in line for message in BASH_NO_TERMINAL))
    )
    if result.returncode or stderr:
        # Build a readable copy of the command for the error message. When the
        # command is a shell running a script (after -c), show a short label
        # instead of the whole script.
        display = list(map(str, command))
        if "-c" in display:
            display[display.index("-c") + 1] = "<startup probe>"

        raise RuntimeError(
            f"Command failed ({result.returncode}): {shlex.join(display)}\n"
            f"{result.stdout}{stderr}"
        )

    return result.stdout


def environment(home, path, temporary):
    """The environment variables for every command this script runs.

    Starting from almost nothing means no settings from the computer running the
    test leak in: not your XDG folders, not shell plugins, and not any private
    variables. LC_ALL=C makes programs use plain, untranslated output, so
    results are the same everywhere; TERM tells the shell what kind of terminal
    it's in.
    """

    return {
        "HOME": str(home),
        "PATH": str(path),
        "TMPDIR": str(temporary),
        "LC_ALL": "C",
        "TERM": "xterm-256color",
    }


def chezmoi_command(chezmoi, source, home, temporary, config):
    """chezmoi, pointed at temporary copies of everything.

    The options:
      --source              the repository to read (normally ~/.local/share/chezmoi)
      --destination         the home folder to write into (normally ~)
      --config, --cache,    chezmoi's settings file, download cache and record of
      --persistent-state    what it has done; temporary ones, so the real ones
                            are neither used nor changed
      --refresh-externals=never  don't download the theme files listed in
                            .chezmoiexternal.toml
      --no-tty              never stop to ask a question
      --no-pager            print output directly, not through a pager like less
    """

    return [
        chezmoi,
        "--source", str(source),
        "--destination", str(home),
        "--config", str(config),
        "--cache", str(temporary / "chezmoi-cache"),
        "--persistent-state", str(temporary / "chezmoi-state.boltdb"),
        "--refresh-externals=never",
        "--no-tty",
        "--no-pager",
    ]


def render(binaries, source, home, temporary, config, search_path):
    """Write this computer's startup files into a fake home, then check them.

    This only uses chezmoi commands that read (`managed`, `cat`, `source-path`).
    It never runs `chezmoi init`, which writes chezmoi's settings file and,
    unless told otherwise with --config-path, would overwrite the real one.
    """

    home.mkdir(parents=True)

    # ~/.local/bin, which conf.d/20-path.fish puts first. fish_add_path only
    # adds folders that exist; install.sh creates this one on a real machine.
    (home / ".local/bin").mkdir(parents=True)
    env = environment(home, search_path, temporary)
    command = chezmoi_command(binaries["chezmoi"], source, home, temporary, config)

    # `chezmoi managed` lists every file chezmoi would put in the home folder. None
    # of the repository's own files (this script, the README, install.sh, the
    # GitHub workflows) may be among them: they live outside home/, the folder
    # that .chezmoiroot tells chezmoi to use.
    managed = run(
        command + ["managed", "--include=files", "--path-style=relative"], env, home
    ).splitlines()
    if any(path.split("/")[0] in (".github", "scripts", "README.md", "install.sh")
           for path in managed):
        raise RuntimeError("Repository files must stay outside the source state")

    # The files to check: everything in fish's folder, and this system's login
    # file (and ~/.bash_profile, which chezmoi writes here on Linux because the
    # fake home has no login file of its own).
    targets = [Path(path) for path in managed
               if path.startswith(f"{FISH_DIR}/")
               or path in (str(LOGIN_FILE), ".bash_profile")]
    if LOGIN_FILE not in targets:
        raise RuntimeError(f"chezmoi does not manage ~/{LOGIN_FILE} on this system")

    for relative in targets:
        target = home / relative
        target.parent.mkdir(parents=True, exist_ok=True)

        # `chezmoi cat FILE` prints what chezmoi would write to FILE, with its
        # template parts filled in. Save that into the fake home folder.
        target.write_text(run(command + ["cat", str(target)], env, home))

        if relative.suffix == ".fish":
            # fish --no-execute only reads the file and reports syntax errors.
            run([binaries["fish"], "--no-execute", str(target)], env, home)

            # fish_indent --check fails if fish_indent would format the file
            # differently. Skip files whose text a program generated.
            origin = Path(run(command + ["source-path", str(target)], env, home).strip())
            if not any(marker in origin.read_text() for marker in GENERATED):
                run([binaries["fish_indent"], "--check", str(target)], env, home)
        elif relative == Path(".zprofile"):
            # zsh -n only reads the file and reports syntax errors. -d and -f
            # stop zsh from reading any other startup files first.
            run([binaries["zsh"], "-d", "-f", "-n", str(target)], env, home)
        else:
            # The same for bash (bash's syntax check is -n too).
            run([binaries["bash"], "--norc", "--noprofile", "-n", str(target)], env, home)

    return targets


def make_mock_homebrew(prefix):
    """A pretend Homebrew: a tiny shell script at "<prefix>/bin/brew".

    The startup files run `brew shellenv SHELL`: brew prints the commands that
    add Homebrew's folders to PATH, and the shell runs them. This stand-in prints
    the same kind of commands for fish, zsh and bash, plus one that sets
    DOTFILES_TEST_BREW_LOADED so the checks can tell whether it was loaded, and
    fails if it is run any other way. shlex.quote() puts quotes around the
    paths, which contain spaces.
    """

    (prefix / "bin").mkdir(parents=True)
    bin_dir = shlex.quote(str(prefix / "bin"))
    fish = [
        "set --global --export DOTFILES_TEST_BREW_LOADED 1",
        f"fish_add_path --global --move --path {bin_dir}",
    ]
    posix = [
        "export DOTFILES_TEST_BREW_LOADED=1",
        f"export PATH={bin_dir}:\"$PATH\"",
    ]
    brew = prefix / "bin/brew"
    brew.write_text(
        '#!/bin/sh\n[ "$1" = shellenv ] || exit 1\ncase $2 in\n'
        "  fish) printf '%s\\n' " + " ".join(map(shlex.quote, fish)) + " ;;\n"
        "  zsh | bash) printf '%s\\n' " + " ".join(map(shlex.quote, posix)) + " ;;\n"
        "  *) exit 1 ;;\nesac\n"
    )
    brew.chmod(0o755)  # make it runnable, like a real program

    # Both editors are installed in the pretend Homebrew. They must never be
    # launched during startup; only their presence on PATH matters.
    for name in ("micro", "fresh"):
        editor = prefix / "bin" / name
        editor.write_text("#!/bin/sh\nexit 1\n")
        editor.chmod(0o755)


def check_fish(binaries, home, shell_bin, mock_bin, temporary, with_brew, scenario):
    """Start fish in all four modes and run PROBE in each."""

    for interactive in (False, True):
        for login in (False, True):
            env = environment(home, shell_bin, temporary)

            # Pretend this is an SSH session. SSH sets SSH_CONNECTION when you
            # log in to a computer remotely, and programs can check it to behave
            # differently. The startup files must still work there, silently
            # (see run()).
            env["SSH_CONNECTION"] = "127.0.0.1 12345 127.0.0.1 22"

            # fish's conf.d sets up Homebrew in every fish, so the pretend one
            # must be loaded whenever it exists.
            env["DOTFILES_EXPECT_BREW"] = str(int(with_brew))
            env["DOTFILES_EXPECT_EDITOR"] = "micro" if with_brew else "vi"
            env["DOTFILES_OPTIONAL_TOOLS"] = OPTIONAL_TOOLS
            env["DOTFILES_MOCK_BIN"] = str(mock_bin)

            # A login fish on macOS runs path_helper (see PROBE).
            system_paths = login and sys.platform == "darwin"
            env["DOTFILES_SYSTEM_PATHS"] = str(int(system_paths))

            # -i makes fish interactive, -l makes it a login shell (on macOS,
            # this also runs fish's copy of path_helper), and -c runs PROBE.
            command = [binaries["fish"]]
            if interactive:
                command.append("--interactive")

            if login:
                command.append("--login")

            output = run(command + ["-c", PROBE], env, home)
            if output != "dotfiles-shell-ok\n":
                raise RuntimeError(f"Unexpected startup output: {output!r}")

            mode = "interactive" if interactive else "noninteractive"
            kind = "login" if login else "non-login"
            print(f"PASS: fish, {scenario}, {mode} {kind} startup", flush=True)


def check_login_shell(binaries, home, shell_bin, temporary, with_brew, scenario):
    """Start this system's login shell the ways that matter.

    macOS: zsh reads ~/.zprofile in login shells (every new Ghostty window),
    but not for `zsh -c`. -d skips the system-wide files in /etc (all but
    zshenv), so only this repository's file is tested.
    Linux: bash reads ~/.bashrc in interactive shells (an SSH login reaches it
    through ~/.bash_profile here), but commands like `bash -c` and `ssh host
    command` must get nothing from it.
    """

    if sys.platform == "darwin":
        cases = [
            ("zsh -l", [binaries["zsh"], "-d", "-l"], True),
            ("zsh -l -i", [binaries["zsh"], "-d", "-l", "-i"], True),
            ("zsh -c", [binaries["zsh"], "-d"], False),
        ]
    else:
        cases = [
            ("bash -i", [binaries["bash"], "-i"], True),
            ("bash -l -i", [binaries["bash"], "-l", "-i"], True),
            ("bash -l", [binaries["bash"], "-l"], False),
            ("bash -c", [binaries["bash"]], False),
        ]

    # Unlike zsh, bash can't skip the system's own startup files (/etc/profile,
    # and on Debian and Ubuntu /etc/bash.bashrc), and those expect the system's
    # folders on PATH, so they come after the empty folder here.
    path = shell_bin if sys.platform == "darwin" else f"{shell_bin}:{os.defpath}"

    # Workaround: Ubuntu's /etc/bash.bashrc prints a hint about sudo in every
    # interactive bash of a user in the sudo group (as on GitHub's machines),
    # unless the home folder has a .sudo_as_admin_successful file.
    if sys.platform == "linux":
        (home / ".sudo_as_admin_successful").touch()

    # The shell prints whether the pretend Homebrew was loaded, and nothing else.
    probe = 'echo "brew=${DOTFILES_TEST_BREW_LOADED:-0}"'
    for label, command, loads in cases:
        env = environment(home, path, temporary)
        env["SSH_CONNECTION"] = "127.0.0.1 12345 127.0.0.1 22"
        output = run(command + ["-c", probe], env, home)
        expected = f"brew={int(with_brew and loads)}\n"
        if output != expected:
            raise RuntimeError(f"{label}: expected {expected!r}, got {output!r}")

        print(f"PASS: {label}, {scenario}", flush=True)


def main():
    if sys.platform not in ("darwin", "linux"):
        raise RuntimeError("These checks require macOS or Linux")

    # Find chezmoi, fish, fish_indent and this system's login shell; stop if
    # one is missing. shutil.which(name) does what `command -v` does in a shell.
    login_shell = "zsh" if sys.platform == "darwin" else "bash"
    binaries = {name: shutil.which(name)
                for name in ("chezmoi", "fish", "fish_indent", login_shell)}
    for name, binary in binaries.items():
        if not binary:
            raise RuntimeError(f"Required command not found: {name}")

    # The normal PATH, used only while chezmoi renders the files.
    search_path = os.environ.get("PATH", os.defpath)

    # A temporary folder that Python deletes automatically when the
    # `with` block ends, even if a check fails.
    with tempfile.TemporaryDirectory(prefix="dotfiles-shell-") as directory:
        temporary = Path(directory)

        # chezmoi settings with made-up answers to the questions that
        # home/.chezmoi.toml.tmpl asks (Git name and email, whether this
        # machine publishes changes, and whether it may use sudo), so the
        # templates can be rendered.
        config = temporary / "chezmoi.toml"
        config.write_text(
            '[git]\nautoCommit = false\nautoPush = false\n'
            '[data]\ngitName = "Shell checks"\ngitEmail = "checks@example.invalid"\n'
            'publishDotfiles = false\nuseSudo = false\n'
        )

        # Step 1: render the unmodified templates, with the real Homebrew
        # detection on this computer, and check that they parse.
        render(binaries, SOURCE, temporary / "native home", temporary, config, search_path)
        print(f"PASS: native {sys.platform} template rendering, syntax and formatting",
              flush=True)

        # Step 2: start the shells in every mode. Work on a copy of the
        # repository ("fixture"), because the Homebrew detection is replaced
        # below. The copy leaves out .git, which isn't needed.
        fixture = temporary / "source"
        shutil.copytree(SOURCE, fixture, ignore=shutil.ignore_patterns(".git"))
        state = fixture / STATE_NAME

        # An empty folder that becomes the shells' whole PATH, so that optional
        # tools on this computer are never found by accident. (On macOS, a
        # login fish adds the system's folders from /etc/paths.)
        shell_bin = temporary / "shell-bin"
        shell_bin.mkdir()

        prefix = temporary / "mock homebrew"
        make_mock_homebrew(prefix)

        for with_brew in (False, True):
            scenario = "with Homebrew" if with_brew else "without Homebrew"

            # The space in the folder name is deliberate: it catches any place in
            # the startup files that forgets to put quotes around a path.
            home = temporary / scenario / "home with spaces"

            # The brew-prefix template normally finds the real Homebrew. Only in
            # this temporary copy, replace it with the pretend Homebrew's folder,
            # or with nothing to simulate a machine without Homebrew, so the test
            # never runs the real Homebrew or other programs on this computer.
            (state / ".chezmoitemplates/brew-prefix").write_text(
                str(prefix) if with_brew else ""
            )
            render(binaries, fixture, home, temporary, config, search_path)
            check_fish(binaries, home, shell_bin, prefix / "bin", temporary, with_brew,
                       scenario)
            check_login_shell(binaries, home, shell_bin, temporary, with_brew, scenario)


# Run main() when this file is run as a program (not when another Python file
# imports it). Expected kinds of failure are printed as one FAIL line and end
# the script with exit status 1, which is how CI knows the check failed.
if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
