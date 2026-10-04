#!/usr/bin/env python3
"""Check the native OS's shell configuration using isolated temporary homes."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


SOURCE = Path(__file__).resolve().parents[1]
STARTUP_FILES = [Path(".zshenv")] + [
    Path(".config/zsh") / name
    for name in (".zshenv", ".zprofile", ".zshrc", ".zlogin", ".zlogout")
]
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
    result = subprocess.run(
        command, env=env, cwd=cwd, text=True, capture_output=True, timeout=30
    )
    if result.returncode or result.stderr:
        display = list(map(str, command))
        if "-c" in display:
            display[display.index("-c") + 1] = "<startup probe>"
        raise RuntimeError(
            f"Command failed ({result.returncode}): {shlex.join(display)}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result.stdout


def environment(home, path, temporary):
    # Do not inherit ZDOTDIR, XDG overrides, shell plugins, or private variables.
    return {
        "HOME": str(home),
        "PATH": str(path),
        "TMPDIR": str(temporary),
        "LC_ALL": "C",
        "TERM": "xterm-256color",
    }


def render(chezmoi, zsh, source, home, temporary, config, search_path):
    home.mkdir(parents=True)
    env = environment(home, search_path, temporary)
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
    managed = run(
        command + ["managed", "--include=files", "--path-style=relative"], env, home
    ).splitlines()
    if any(path.split("/")[0] in (".github", "scripts") for path in managed):
        raise RuntimeError("CI files must be excluded by .chezmoiignore")
    for relative in STARTUP_FILES:
        target = home / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(run(command + ["cat", str(target)], env, home))
        run([zsh, "-d", "-f", "-n", str(target)], env, home)


def main():
    if sys.platform not in ("darwin", "linux"):
        raise RuntimeError("These checks require macOS or Linux")
    utilities = ("mkdir", "mv", "sed", "grep")  # Used by compinit/compdump/compaudit.
    binaries = {name: shutil.which(name) for name in ("chezmoi", "zsh") + utilities}
    for name, binary in binaries.items():
        if not binary:
            raise RuntimeError(f"Required command not found: {name}")
    search_path = os.environ.get("PATH", os.defpath)
    with tempfile.TemporaryDirectory(prefix="dotfiles-shell-") as directory:
        temporary = Path(directory)
        config = temporary / "chezmoi.toml"
        config.write_text(
            '[git]\nautoCommit = false\nautoPush = false\n'
            '[data]\ngitName = "Shell checks"\ngitEmail = "checks@example.invalid"\n'
            'publishDotfiles = false\n'
        )

        # First check the unmodified templates with native Homebrew detection.
        render(
            binaries["chezmoi"], binaries["zsh"], SOURCE,
            temporary / "native home", temporary, config, search_path
        )
        print(f"PASS: native {sys.platform} template rendering and Zsh syntax", flush=True)

        fixture = temporary / "source"
        shutil.copytree(SOURCE, fixture, ignore=shutil.ignore_patterns(".git"))
        shell_bin = temporary / "shell-bin"
        shell_bin.mkdir()
        for name in utilities:
            (shell_bin / name).symlink_to(binaries[name])
        prefix = temporary / "mock homebrew"
        (prefix / "bin").mkdir(parents=True)
        (prefix / "share/zsh/site-functions").mkdir(parents=True)
        brew = prefix / "bin/brew"
        exports = [
            "export DOTFILES_TEST_BREW_LOADED=1",
            f"export PATH={shlex.quote(str(prefix / 'bin'))}:\"$PATH\"",
            f"export FPATH={shlex.quote(str(prefix / 'share/zsh/site-functions'))}:${{FPATH:-}}",
        ]
        brew.write_text(
            '#!/bin/sh\n[ "$1" = shellenv ] && [ "$2" = zsh ] || exit 1\n'
            + "printf '%s\\n' " + " ".join(map(shlex.quote, exports)) + "\n"
        )
        brew.chmod(0o755)

        for with_brew in (False, True):
            scenario = "with Homebrew" if with_brew else "without Homebrew"
            home = temporary / scenario / "home with spaces"
            # Control detection only in this temporary source copy. Never execute
            # real Homebrew or optional programs installed on the host machine.
            (fixture / ".chezmoitemplates/brew-prefix").write_text(
                str(prefix) if with_brew else ""
            )
            render(
                binaries["chezmoi"], binaries["zsh"], fixture, home,
                temporary, config, search_path
            )
            for interactive in (False, True):
                for login in (False, True):
                    env = environment(home, shell_bin, temporary)
                    env["SSH_CONNECTION"] = "127.0.0.1 12345 127.0.0.1 22"
                    expected_brew = with_brew and (
                        login if sys.platform == "darwin" else interactive
                    )
                    env["DOTFILES_EXPECT_BREW"] = str(int(expected_brew))
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


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
