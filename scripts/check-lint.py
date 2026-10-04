#!/usr/bin/env python3
"""Lint shell scripts and GitHub workflows without running the setup scripts.

Run with Python 3.8+, chezmoi, shellcheck, shfmt and actionlint on PATH.
Chezmoi templates are rendered for macOS and Linux into temporary files before
ShellCheck reads them. shfmt checks their rendered formatting using the original
relative filenames in a temporary home with home/dot_editorconfig installed.
Zsh startup files are checked separately by check-shell.py; ShellCheck does not
support Zsh.
"""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


SOURCE = Path(__file__).resolve().parents[1]
STATE = SOURCE / (SOURCE / ".chezmoiroot").read_text().strip()
SHELL_SUFFIXES = (".sh", ".bash", ".bats", ".dash", ".ksh")


def run(command, env, input=None):
    """Capture output so a failed check shows its command and diagnostics."""
    result = subprocess.run(
        command, cwd=SOURCE, env=env, input=input,
        text=True, capture_output=True, timeout=30,
    )
    if result.returncode:
        raise RuntimeError(
            f"{shlex.join(map(str, command))}\n{result.stdout}{result.stderr}"
        )
    return result.stdout


def shell_files():
    """Include tracked and new scripts, including shell template fragments."""
    paths = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=SOURCE,
    ).decode().split("\0")
    for relative in sorted(set(paths) - {""}):
        path = SOURCE / relative
        if not path.is_file():
            continue
        name = path.name[:-5] if path.name.endswith(".tmpl") else path.name
        if name.endswith(SHELL_SUFFIXES):
            yield path
        elif "." not in name:
            # Extensionless scripts are identified by their shell shebang.
            first = path.read_bytes().split(b"\n", 1)[0].decode(errors="replace")
            if first.startswith("#!") and first.split()[-1].split("/")[-1] in (
                "sh", "bash", "dash", "ksh", "mksh",
            ):
                yield path


def main():
    binaries = {
        name: shutil.which(name)
        for name in ("chezmoi", "shellcheck", "shfmt", "actionlint")
    }
    for name, binary in binaries.items():
        if not binary:
            raise RuntimeError(f"Required command not found: {name}")

    with tempfile.TemporaryDirectory(prefix="dotfiles-lint-") as directory:
        temporary = Path(directory)
        home = temporary / "home with spaces"
        home.mkdir()
        # Use the deployed config layout without applying the real dotfiles or
        # depending on an EditorConfig file in the checkout or runner's home.
        shutil.copyfile(STATE / "dot_editorconfig", home / ".editorconfig")
        config = temporary / "chezmoi.toml"
        config.write_text(
            '[git]\nautoCommit = false\nautoPush = false\n'
            '[data]\ngitName = "Lint checks"\ngitEmail = "checks@example.invalid"\n'
            'publishDotfiles = false\n'
        )
        # Keep local configs and private environment variables out of the checks.
        env = {
            "HOME": str(home),
            "PATH": os.environ.get("PATH", os.defpath),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_CACHE_HOME": str(temporary / "cache"),
            "TMPDIR": str(temporary),
            "LC_ALL": "C",
        }
        chezmoi = [
            binaries["chezmoi"], "--source", str(SOURCE),
            "--destination", str(home), "--config", str(config),
            "--cache", str(temporary / "chezmoi-cache"),
            "--persistent-state", str(temporary / "chezmoi-state.boltdb"),
            "--refresh-externals=never", "--no-tty", "--no-pager",
            "execute-template",
        ]
        checks = 0
        failures = []
        for path in shell_files():
            template = path.suffix == ".tmpl" or ".chezmoitemplates" in path.parts
            variants = (
                (("darwin", "arm64"), ("darwin", "amd64"), ("linux", "amd64"))
                if template else ((None, None),)
            )
            for system, arch in variants:
                label = str(path.relative_to(SOURCE))
                content = path.read_text()
                if template:
                    label += f" ({system}/{arch})"
                    context = {
                        "os": system, "arch": arch,
                        "homeDir": str(home), "sourceDir": str(STATE),
                    }
                    fields = " ".join(
                        f"{json.dumps(key)} {json.dumps(value)}"
                        for key, value in context.items()
                    )
                    content = run(
                        chezmoi, env,
                        '{{ with dict "chezmoi" (dict ' + fields + ') }}'
                        + content + '{{ end }}',
                    )

                # Keep ordinary scripts in place so relative source statements
                # resolve correctly. Templates need a temporary rendered copy.
                rendered = path
                if template:
                    name = path.name[:-5] if path.suffix == ".tmpl" else path.name
                    rendered = temporary / name
                    rendered.write_text(content)
                shellcheck = [
                    binaries["shellcheck"], "--rcfile",
                    str(STATE / "dot_config/shellcheckrc"),
                ]
                if template:
                    shellcheck += ["--source-path", str(path.parent)]
                if not content.startswith("#!") and rendered.suffix == ".sh":
                    shellcheck += ["--shell=sh"]
                format_path = home / path.relative_to(SOURCE)
                format_path.parent.mkdir(parents=True, exist_ok=True)
                commands = [
                    (shellcheck + [str(rendered)], None),
                    ([binaries["shfmt"], "--diff", "--filename", str(format_path)], content),
                ]
                for command, input in commands:
                    try:
                        run(command, env, input)
                    except RuntimeError as error:
                        failures.append(f"{label}: {error}")
                checks += 1

        try:
            run([binaries["actionlint"], "-shellcheck", binaries["shellcheck"]], env)
        except RuntimeError as error:
            failures.append(str(error))
        if failures:
            raise RuntimeError("\n\n".join(failures))
        print(f"PASS: ShellCheck and shfmt ({checks} script variants), all workflows")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
