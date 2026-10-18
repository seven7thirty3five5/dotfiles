#!/usr/bin/env python3
"""Check setup permissions, recovery and update scope without installing anything.

Run with python3 scripts/check-behavior.py. Chezmoi renders the real package
script; recording commands replace installers and updaters in temporary homes.
Assertions cover the resulting packages, machine state and exit status, rather
than requiring a particular sequence of internal commands.
"""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]
STATE_NAME = (SOURCE / ".chezmoiroot").read_text().strip()


class BehaviorChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-behavior-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.home = self.root / "home with spaces"
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}{os.pathsep}{os.defpath}",
            "TMPDIR": str(self.root), "LC_ALL": "C", "TERM": "xterm-256color",
        }

    def command(self, name, body):
        """A recording command, using this Python directly instead of PATH."""
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
        return path

    def run_command(self, command, cwd=None, success=True):
        result = subprocess.run(
            command, cwd=cwd or self.home, env=self.env, text=True,
            capture_output=True, timeout=30, stdin=subprocess.DEVNULL,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_package_permissions(self):
        """The permission choice reaches Homebrew and its rendered cask list."""
        fixture = self.root / "source"
        shutil.copytree(SOURCE / "home", fixture / "home")
        (fixture / ".chezmoiroot").write_text(STATE_NAME)
        (fixture / "home/.chezmoitemplates/brew-prefixes").write_text(str(self.home / ".local"))
        self.command("brew", '''import json, os, pathlib, sys
if sys.argv[1:3] == ['shellenv', 'sh']:
    pass
elif sys.argv[1] == 'bundle':
    pathlib.Path(os.environ['HOME'], 'bundle.json').write_text(json.dumps({
        'brewfile': sys.stdin.read(), 'no_sudo': os.environ.get('HOMEBREW_NO_SUDO'),
    }))
else:
    raise SystemExit('Unexpected Homebrew command')
''')
        chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(chezmoi, "chezmoi is required")
        for system in ("darwin", "linux"):
            for use_sudo in (False, True):
                with self.subTest(system=system, useSudo=use_sudo):
                    config = self.root / "chezmoi.toml"
                    config.write_text('[data]\ngitName="Checks"\ngitEmail="checks@example.invalid"\n'
                                      f'publishDotfiles=false\nuseSudo={str(use_sudo).lower()}\n')
                    context = ('{{ with dict "chezmoi" (dict "os" ' + json.dumps(system)
                               + ' "arch" "arm64" "homeDir" ' + json.dumps(str(self.home))
                               + ') "useSudo" ' + str(use_sudo).lower() + ' }}'
                               + (fixture / "home/.chezmoiscripts/run_onchange_after_30-install-packages.sh.tmpl").read_text()
                               + '{{ end }}')
                    command = [chezmoi, "--source", str(fixture), "--destination", str(self.home),
                               "--config", str(config), "--cache", str(self.root / "cache"),
                               "--persistent-state", str(self.root / "state"),
                               "--refresh-externals=never", "--no-tty", "execute-template", context]
                    script = self.root / "packages.sh"
                    script.write_text(self.run_command(command).stdout)
                    self.run_command(["/bin/sh", str(script)])
                    bundle = json.loads((self.home / "bundle.json").read_text())
                    self.assertEqual(bundle["no_sudo"], None if use_sudo else "1")
                    self.assertIn('brew "fish"', bundle["brewfile"])
                    for cask in ("docker-desktop", "logi-options+"):
                        self.assertEqual(f'cask "{cask}"' in bundle["brewfile"],
                                         system == "darwin" and use_sudo)

    def test_setup_recovery(self):
        """Recovered setup succeeds and renders files using the recovered tools."""
        source = self.root / "source"
        (source / ".git").mkdir(parents=True)
        (source / ".git/config").write_text(
            '[remote "origin"]\nurl=https://github.com/seven7thirty3five5/dotfiles.git\n'
        )
        self.env["DOTFILES_TEST_SOURCE"] = str(source)
        # No system changes or downloads are allowed in this scenario.
        for name in ("curl", "cc", "file", "git"):
            self.command(name, "raise SystemExit('Unexpected external command')\n")
        self.command("id", "print(1000)\n")
        self.command("brew", "import sys\nraise SystemExit(0 if sys.argv[1:] == ['shellenv', 'sh'] else 1)\n")
        self.command("chezmoi", '''import os, pathlib, sys
home = pathlib.Path(os.environ['HOME'])
installed = home / 'brew-installed'
args = sys.argv[1:]
if args[0] == 'execute-template':
    text = args[1]
    if '.chezmoi.os }}/' in text:
        print(os.environ.get('DOTFILES_TEST_OS', 'linux') + '/arm64')
    elif '.chezmoi.workingTree' in text:
        print(os.environ['DOTFILES_TEST_SOURCE'])
    elif 'brew-prefix' in text:
        if installed.exists():
            print(home / '.local')
    elif 'sudo-casks' in text:
        if os.environ.get('DOTFILES_TEST_OS') == 'darwin':
            print('docker-desktop\\nlogi-options+')
    elif '.useSudo' in text:
        print('false')
    elif '.chezmoi.os' in text:
        print(os.environ.get('DOTFILES_TEST_OS', 'linux'))
    else:
        raise SystemExit('Unexpected template: ' + text)
elif args[0] in ('init', 'apply'):
    applies = args[0] == 'apply' or '--apply' in args
    if applies:
        if '--include=scripts' not in args:
            (home / 'rendered-prefix').write_text(str(home / '.local') if installed.exists() else '')
        if '--exclude=scripts' not in args:
            if not (home / 'attempted').exists():
                (home / 'attempted').touch()
                raise SystemExit(1)
            if os.environ['DOTFILES_TEST_RECOVERY'] == 'fail':
                raise SystemExit(1)
            installed.touch()
else:
    raise SystemExit('Unexpected chezmoi command')
''')
        for recovery in ("succeed", "fail"):
            with self.subTest(recovery=recovery):
                for name in ("attempted", "brew-installed", "rendered-prefix"):
                    (self.home / name).unlink(missing_ok=True)
                self.env["DOTFILES_TEST_RECOVERY"] = recovery
                result = self.run_command(["/bin/sh", str(SOURCE / "install.sh")], success=False)
                if recovery == "succeed":
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn("Install Homebrew:", result.stdout)
                    self.assertEqual((self.home / "rendered-prefix").read_text(), str(self.home / ".local"))
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Install Homebrew:", result.stdout)

        # A Mac may already have Homebrew while declining sudo: setup succeeds,
        # and missing privileged apps become administrator tasks, not installers.
        self.env.update(DOTFILES_TEST_OS="darwin", DOTFILES_TEST_RECOVERY="succeed")
        result = self.run_command(["/bin/sh", str(SOURCE / "install.sh")])
        for cask in ("docker-desktop", "logi-options+"):
            self.assertIn(f"Ask IT (an administrator) to install the Homebrew cask {cask}.",
                          result.stdout)

    def test_update_scope_and_failure(self):
        """Updating inside a project targets the machine, and failures stop work."""
        fish = shutil.which("fish")
        self.assertIsNotNone(fish, "fish is required")
        project = self.home / "project"
        project.mkdir()
        (project / "mise.toml").write_text('[tools]\nnode="20"\n')
        recorder = '''import json, os, pathlib, sys
home = pathlib.Path(os.environ['HOME'])
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with (home / 'commands.jsonl').open('a') as stream:
    stream.write(json.dumps([name, args]) + '\\n')
if name == os.environ.get('DOTFILES_TEST_FAIL_TOOL'):
    raise SystemExit(23)
if name == 'mise' and args[0] == 'upgrade':
    target = home if '--global' in args or pathlib.Path.cwd() == home else pathlib.Path.cwd()
    (target / 'runtime-updated').touch()
if name == 'mise' and 'exec' in args:
    import subprocess
    cwd = args[args.index('--cd') + 1] if '--cd' in args else os.getcwd()
    env = dict(os.environ)
    env['PATH'] = str(home / '.local/bin') + os.pathsep + env['PATH']
    raise SystemExit(subprocess.call(args[args.index('--') + 1:], cwd=cwd, env=env))
if name == 'pnpm':
    (home / 'skills-runtime').write_text('global')
'''
        for name in ("chezmoi", "brew", "mise", "pnpm", "gh", "herdr"):
            self.command(name, recorder)
        # An activated project can put a different pnpm first on PATH. --dir
        # alone changes its directory, not which pnpm and Node were selected.
        project_bin = project / "bin"
        project_bin.mkdir()
        project_pnpm = project_bin / "pnpm"
        project_pnpm.write_text(f"#!{sys.executable}\nimport os, pathlib\n"
                                "pathlib.Path(os.environ['HOME'], 'skills-runtime').write_text('project')\n")
        project_pnpm.chmod(0o755)
        self.env["PATH"] = str(project_bin) + os.pathsep + self.env["PATH"]
        functions = SOURCE / "home/dot_config/fish/functions"
        script = "\n".join(f"source {shlex.quote(str(functions / name))}" for name in (
            "_dotfiles_section.fish", "_dotfiles_subsection.fish", "update.fish",
        )) + "\nupdate\n"
        log = self.home / "commands.jsonl"
        for failure in ("", "brew", "mise"):
            with self.subTest(failure=failure or "none"):
                log.unlink(missing_ok=True)
                self.env["DOTFILES_TEST_FAIL_TOOL"] = failure
                result = self.run_command([fish, "--no-config", "-c", script], cwd=project,
                                          success=not failure)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                if failure:
                    self.assertEqual(result.returncode, 23)
                    self.assertEqual(calls[-1][0], failure)
                else:
                    self.assertTrue((self.home / "runtime-updated").exists())
                    self.assertFalse((project / "runtime-updated").exists())
                    self.assertEqual((self.home / "skills-runtime").read_text(), "global")
                    self.assertEqual((project / "mise.toml").read_text(), '[tools]\nnode="20"\n')
                    self.assertIn("herdr", [name for name, _ in calls])


if __name__ == "__main__":
    unittest.main(verbosity=2)
