#!/usr/bin/env python3
"""Check that the zsh startup files work, without touching your real home folder.

What this tests
---------------
zsh reads up to five startup files of yours: .zshenv, .zprofile, .zshrc and
.zlogin when it starts, and .zlogout when a login shell exits. Which ones it
reads depends on how it was started:

  - every shell, even one that just runs a script, reads .zshenv;
  - a "login" shell (a new terminal tab on macOS, or an SSH session) also reads
    .zprofile and .zlogin;
  - an "interactive" shell (one you type into) also reads .zshrc.

These dotfiles depend on those rules. For example, they set up Homebrew in
.zprofile on macOS but in .zshrc on Linux, because that is what Homebrew's own
instructions recommend for each system. This script checks that by:

  1. asking chezmoi to produce ("render") the startup files from their templates,
     and checking that zsh can read them without syntax errors;
  2. starting zsh in all four combinations of login or not and interactive or
     not, once with a pretend Homebrew and once without, and running a small zsh
     script (PROBE, below) that checks the environment the startup files set up.

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

# The startup files to check, as paths inside a home folder. ~/.zshenv is the
# only one that lives directly in the home folder: it tells zsh (through ZDOTDIR)
# to read the other files from ~/.config/zsh instead.
STARTUP_FILES = [Path(".zshenv")] + [
    Path(".config/zsh") / name
    for name in (".zshenv", ".zprofile", ".zshrc", ".zlogin", ".zlogout")
]

# PROBE is a small zsh script that runs right after zsh has read the startup
# files. Each line checks one thing; if it's wrong, fail() prints a message as an
# error and stops with exit status 1. The checks:
#
#   ZDOTDIR == ~/.config/zsh          ~/.zshenv moved zsh's files to ~/.config/zsh.
#   XDG_*_HOME == the usual folders   The XDG folders (where programs keep config,
#                                     data, state and cache files) are set.
#   $path[1] == ~/.local/bin          Your own programs in ~/.local/bin come first
#                                     on PATH, before Homebrew's.
#   EDITOR and VISUAL == vi           nvim isn't available in this test, so the
#                                     fallback editor, vi, was chosen.
#   DOTFILES_TEST_BREW_LOADED         The pretend Homebrew sets this to 1 when it is
#     == DOTFILES_EXPECT_BREW         loaded. It must be loaded in exactly the
#                                     shells where it should be (see main()).
#   optional tools are not found      Proves the test isn't using programs that
#                                     happen to be installed on this computer.
#   compdef exists (interactive)      zsh's tab completion system was set up.
#
# Finally it prints "dotfiles-shell-ok". That must be the only output: anything
# else the startup files print would be a bug (see run() below).
#
# The r"""...""" form is a "raw" multi-line string: Python keeps the backslashes
# and quotes inside it exactly as written.
PROBE = r"""
fail() { print -ru2 -- "$1"; exit 1; }
[[ "$ZDOTDIR" == "$HOME/.config/zsh" ]] || fail 'ZDOTDIR was not initialized'
[[ "$XDG_CONFIG_HOME" == "$HOME/.config" ]] || fail 'Unexpected config directory'
[[ "$XDG_DATA_HOME" == "$HOME/.local/share" ]] || fail 'Unexpected data directory'
[[ "$XDG_STATE_HOME" == "$HOME/.local/state" ]] || fail 'Unexpected state directory'
[[ "$XDG_CACHE_HOME" == "$HOME/.cache" ]] || fail 'Unexpected cache directory'
[[ "$path[1]" == "$HOME/.local/bin" ]] || fail '~/.local/bin lost PATH priority'
[[ "$EDITOR" == vi && "$VISUAL" == vi ]] || fail 'Missing editor fallback'
[[ ${DOTFILES_TEST_BREW_LOADED:-0} == "$DOTFILES_EXPECT_BREW" ]] || fail 'Homebrew initialized in the wrong shell mode'
for tool in nvim spf eza fzf atuin zoxide starship lazydocker; do
  (( ! $+commands[$tool] )) || fail "Optional tool unexpectedly available: $tool"
done
if [[ -o interactive ]]; then
  (( $+functions[compdef] )) || fail 'Interactive completion was not initialized'
fi
print -r -- dotfiles-shell-ok
"""


def run(command, env, cwd):
    """Run a command and return what it printed.

    Raise an error if the command fails, and also if it prints anything at all as
    an error message (to stderr). That strictness is deliberate: startup files
    must be completely silent, because anything they print can break programs
    that talk to another computer over SSH, such as scp, rsync and git. So even
    a harmless-looking warning counts as a failure.

    timeout=30 stops a command that hangs, for example one waiting for input.
    """
    result = subprocess.run(
        command, env=env, cwd=cwd, text=True, capture_output=True, timeout=30
    )
    if result.returncode or result.stderr:
        # Build a readable copy of the command for the error message. When the
        # command is zsh running the PROBE script (after -c), show a short label
        # instead of the whole script.
        display = list(map(str, command))
        if "-c" in display:
            display[display.index("-c") + 1] = "<startup probe>"
        raise RuntimeError(
            f"Command failed ({result.returncode}): {shlex.join(display)}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result.stdout


def environment(home, path, temporary):
    """The environment variables for every command this script runs.

    Starting from almost nothing means no settings from the computer running the
    test leak in: not your ZDOTDIR or XDG folders, not shell plugins, and not any
    private variables. LC_ALL=C makes programs use plain, untranslated output, so
    results are the same everywhere; TERM tells zsh what kind of terminal it's in.
    """
    return {
        "HOME": str(home),
        "PATH": str(path),
        "TMPDIR": str(temporary),
        "LC_ALL": "C",
        "TERM": "xterm-256color",
    }


def render(chezmoi, zsh, source, home, temporary, config, search_path):
    """Write this computer's startup files into a fake home, then syntax-check them.

    This only uses chezmoi commands that read (`managed`, `cat`). It never runs
    `chezmoi init`, which writes chezmoi's settings file and, unless told
    otherwise with --config-path, would overwrite the real one.
    """
    home.mkdir(parents=True)
    env = environment(home, search_path, temporary)
    # The options that point chezmoi at temporary copies of everything:
    #   --source              the repository to read (normally ~/.local/share/chezmoi)
    #   --destination         the home folder to write into (normally ~)
    #   --config, --cache,    chezmoi's settings file, download cache and record of
    #   --persistent-state    what it has done; temporary ones, so the real ones
    #                         are neither used nor changed
    #   --refresh-externals=never  don't download the theme files listed in
    #                         .chezmoiexternal.toml
    #   --no-tty              never stop to ask a question
    #   --no-pager            print output directly, not through a pager like less
    command = [
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
    for relative in STARTUP_FILES:
        target = home / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        # `chezmoi cat FILE` prints what chezmoi would write to FILE, with its
        # template parts filled in. Save that into the fake home folder.
        target.write_text(run(command + ["cat", str(target)], env, home))
        # zsh -n only reads the file and reports syntax errors, without running
        # anything. -d and -f stop zsh from reading any other startup files first.
        run([zsh, "-d", "-f", "-n", str(target)], env, home)


def main():
    if sys.platform not in ("darwin", "linux"):
        raise RuntimeError("These checks require macOS or Linux")

    # When zsh sets up tab completion, its compinit, compdump and compaudit
    # functions run these four programs. Later, zsh runs with a PATH that
    # contains only these four (see shell_bin), so that optional tools such as
    # nvim or fzf are never found by accident.
    utilities = ("mkdir", "mv", "sed", "grep")

    # Find chezmoi, zsh and the four utilities; stop if one is missing.
    # shutil.which(name) does what `command -v` does in a shell.
    binaries = {name: shutil.which(name) for name in ("chezmoi", "zsh") + utilities}
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
        # home/.chezmoi.toml.tmpl asks (Git name and email, and whether this
        # machine publishes changes), so the templates can be rendered.
        config = temporary / "chezmoi.toml"
        config.write_text(
            '[git]\nautoCommit = false\nautoPush = false\n'
            '[data]\ngitName = "Shell checks"\ngitEmail = "checks@example.invalid"\n'
            'publishDotfiles = false\n'
        )

        # Step 1: render the unmodified templates, with the real Homebrew
        # detection on this computer, and check zsh can parse the results.
        render(
            binaries["chezmoi"], binaries["zsh"], SOURCE,
            temporary / "native home", temporary, config, search_path
        )
        print(f"PASS: native {sys.platform} template rendering and Zsh syntax", flush=True)

        # Step 2: start zsh in every mode. Work on a copy of the repository
        # ("fixture"), because the Homebrew detection is replaced below. The copy
        # leaves out .git, which isn't needed.
        fixture = temporary / "source"
        shutil.copytree(SOURCE, fixture, ignore=shutil.ignore_patterns(".git"))
        # The dotfiles live in the subdirectory named by .chezmoiroot (home/).
        state = fixture / (fixture / ".chezmoiroot").read_text().strip()

        # A folder containing links to just the four utilities; it becomes zsh's
        # whole PATH.
        shell_bin = temporary / "shell-bin"
        shell_bin.mkdir()
        for name in utilities:
            (shell_bin / name).symlink_to(binaries[name])

        # Workaround for GitHub's shared machines: before zsh's tab completion
        # loads files, a safety check (compaudit) makes sure no other user could
        # have changed them; if one could, zsh asks "Ignore insecure directories
        # and continue [y] or abort compinit [n]?". The permissions of zsh's own
        # folders on GitHub's machines can trigger that question, which would fail
        # the test. Rather than turning the safety check off, copy zsh's
        # completion files into private folders (mode 0o700: only this user may
        # read or change them) and point zsh at the copies through FPATH. Copying
        # also means the test doesn't depend on how this computer set up those
        # folders, e.g. with symlinks.
        #
        # First ask a plain zsh (no startup files) where its completion files
        # are: `print -rl -- $fpath` prints its function folders, one per line.
        native_fpath = run(
            [binaries["zsh"], "-d", "-f", "-c", "print -rl -- $fpath"],
            environment(temporary / "native home", search_path, temporary), temporary
        ).splitlines()
        function_root = temporary / "zsh-functions"
        function_root.mkdir(mode=0o700)
        function_paths = []
        for index, directory in enumerate(native_fpath):
            origin = Path(directory)
            if not origin.is_dir():
                continue
            target = function_root / str(index)
            target.mkdir(mode=0o700)
            for entry in origin.iterdir():
                if entry.is_file():
                    shutil.copyfile(entry, target / entry.name)
            function_paths.append(str(target))

        # A pretend Homebrew: a tiny shell script at "mock homebrew/bin/brew".
        # The startup files run `eval "$(brew shellenv zsh)"`: brew prints
        # `export ...` lines that add Homebrew's folders to PATH and FPATH, and
        # eval runs them. This stand-in prints the same kind of lines, plus
        # DOTFILES_TEST_BREW_LOADED=1 so PROBE can tell whether it was loaded,
        # and fails if it is run any other way. shlex.quote() puts quotes around
        # the paths, which contain spaces. In the shell, ${FPATH:-} means
        # "FPATH's current value, or nothing if it isn't set".
        prefix = temporary / "mock homebrew"
        (prefix / "bin").mkdir(parents=True)
        (prefix / "share/zsh/site-functions").mkdir(parents=True)
        brew = prefix / "bin/brew"
        exports = [
            "export DOTFILES_TEST_BREW_LOADED=1",
            f"export PATH={shlex.quote(str(prefix / 'bin'))}:\"$PATH\"",
            f"export FPATH={shlex.quote(str(prefix / 'share/zsh/site-functions'))}"
            ":${FPATH:-}",
        ]
        brew.write_text(
            '#!/bin/sh\n[ "$1" = shellenv ] && [ "$2" = zsh ] || exit 1\n'
            + "printf '%s\\n' " + " ".join(map(shlex.quote, exports)) + "\n"
        )
        brew.chmod(0o755)  # make it runnable, like a real program

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
            render(
                binaries["chezmoi"], binaries["zsh"], fixture, home,
                temporary, config, search_path
            )
            for interactive in (False, True):
                for login in (False, True):
                    env = environment(home, shell_bin, temporary)
                    # The private copies of zsh's completion files (see above).
                    env["FPATH"] = os.pathsep.join(function_paths)
                    # Pretend this is an SSH session. SSH sets SSH_CONNECTION when
                    # you log in to a computer remotely, and programs can check
                    # it to behave differently. The startup files must still
                    # work there, silently (see run()).
                    env["SSH_CONNECTION"] = "127.0.0.1 12345 127.0.0.1 22"
                    # Which shells should load Homebrew: on macOS, login shells
                    # (.zprofile); on Linux, interactive shells (.zshrc). That is
                    # Homebrew's recommendation for each system.
                    expected_brew = with_brew and (
                        login if sys.platform == "darwin" else interactive
                    )
                    env["DOTFILES_EXPECT_BREW"] = str(int(expected_brew))
                    # Start zsh: -d skips the system-wide startup files in /etc
                    # (all but zshenv, which zsh always reads), so only this
                    # repository's files are tested; -i makes it interactive;
                    # -l makes it a login shell; -c runs PROBE.
                    command = [binaries["zsh"], "-d"]
                    if interactive:
                        command.append("-i")
                    if login:
                        command.append("-l")
                    output = run(command + ["-c", PROBE], env, home)
                    if output != "dotfiles-shell-ok\n":
                        raise RuntimeError(f"Unexpected startup output: {output!r}")
                    mode = "interactive" if interactive else "noninteractive"
                    kind = "login" if login else "non-login"
                    print(f"PASS: {scenario}, {mode} {kind} startup", flush=True)


# Run main() when this file is run as a program (not when another Python file
# imports it). Expected kinds of failure are printed as one FAIL line and end
# the script with exit status 1, which is how CI knows the check failed.
if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
