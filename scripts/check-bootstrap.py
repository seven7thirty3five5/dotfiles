#!/usr/bin/env python3
"""Check bootstrap policy and PATH propagation without installing anything."""

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
STATE = SOURCE / (SOURCE / ".chezmoiroot").read_text().strip()


def executable(path, content):
    path.write_text(content)
    path.chmod(0o755)


class BootstrapChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-")
        self.addCleanup(self.directory.cleanup)
        self.temporary = Path(self.directory.name)
        self.home = self.temporary / "home with spaces"
        self.home.mkdir()
        self.bin = self.temporary / "bin"
        self.bin.mkdir()
        self.env = {
            "HOME": str(self.home),
            "PATH": str(self.bin) + os.pathsep + os.defpath,
            "TMPDIR": str(self.temporary),
            "LC_ALL": "C",
        }

    def run_command(self, command, input=None):
        return subprocess.run(
            command, input=input, env=self.env, cwd=self.home,
            text=True, capture_output=True, timeout=30,
        )

    def render(self, template, system):
        chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(chezmoi, "chezmoi is required")
        config = self.temporary / "chezmoi.toml"
        config.write_text('[git]\nautoCommit = false\nautoPush = false\n')
        context = (
            '{{ with dict "chezmoi" (dict "os" '
            + json.dumps(system) + ' "homeDir" '
            + json.dumps(str(self.home)) + ' "sourceDir" '
            + json.dumps(str(STATE)) + ') }}'
        )
        result = self.run_command([
            chezmoi, "--source", str(SOURCE), "--destination", str(self.home),
            "--config", str(config), "--cache", str(self.temporary / "cache"),
            "--persistent-state", str(self.temporary / "state.boltdb"),
            "--no-tty", "--no-pager", "execute-template",
            context + template + "{{ end }}",
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_supported_prefixes(self):
        template = '{{ includeTemplate "brew-prefixes" . }}'
        self.assertEqual(self.render(template, "darwin").splitlines(), ["/opt/homebrew"])
        self.assertEqual(self.render(template, "linux").splitlines(), [
            "/home/linuxbrew/.linuxbrew",
            str(self.home / ".linuxbrew"), str(self.home / ".brew"),
        ])

    def test_install_script_syntax(self):
        for system in ("darwin", "linux"):
            for script in sorted((STATE / ".chezmoiscripts").glob("*.tmpl")):
                with self.subTest(system=system, script=script.name):
                    result = self.run_command(["sh", "-n"], self.render(script.read_text(), system))
                    self.assertEqual(result.returncode, 0, result.stderr)

    def test_macos_install_requires_sudo_and_uses_default_prefix(self):
        executable(self.bin / "uname", '#!/bin/sh\nprintf "%s\\n" "$TEST_ARCH"\n')
        sudo = self.bin / "sudo"
        executable(sudo, '#!/bin/sh\n[ "$TEST_SUDO" = yes ] && exit 0\n'
                   'echo "tester is not in the sudoers file" >&2\nexit 1\n')
        log = self.temporary / "install-log"
        self.env["TEST_INSTALL_LOG"] = str(log)
        # The downloaded installer records its arguments and noninteractive mode.
        installer = 'printf "%s:%s\\n" "$#" "$NONINTERACTIVE" > "$TEST_INSTALL_LOG"\n'
        executable(self.bin / "curl", "#!/bin/sh\nprintf '%s' " + shlex.quote(installer) + "\n")
        template = (STATE / ".chezmoiscripts/run_once_before_10-install-homebrew.sh.tmpl").read_text()
        # Mock only discovery and the sudo binary; never use the host's Homebrew or sudo.
        template = template.replace('{{ template "find-brew.sh" . }}', "brew=\n")
        script = self.render(template, "darwin").replace("/usr/bin/sudo", shlex.quote(str(sudo)))
        self.env.update(TEST_ARCH="arm64", TEST_SUDO="no")
        existing = script.replace("brew=\n", "brew=/opt/homebrew/bin/brew\n")
        result = self.run_command(["sh"], existing)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(log.exists(), "An existing macOS installation must be reused without sudo")
        for architecture, access, expected, message in (
            ("arm64", "no", 1, "requires sudo access for /opt/homebrew"),
            ("x86_64", "yes", 1, "Intel Macs are not supported"),
            ("arm64", "yes", 0, ""),
        ):
            with self.subTest(architecture=architecture, sudo=access):
                self.env.update(TEST_ARCH=architecture, TEST_SUDO=access)
                result = self.run_command(["sh"], script)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertIn(message, result.stderr)
                if expected:
                    self.assertFalse(log.exists(), "Homebrew ran before its prerequisites passed")
                else:
                    self.assertEqual(log.read_text(), "0:1\n", "macOS must use the default prefix")

    def installer_fixture(self):
        prefix = self.temporary / "mock homebrew"
        brew_bin = prefix / "bin"
        brew_bin.mkdir(parents=True)
        exports = [
            'export PATH=' + shlex.quote(str(brew_bin)) + ':"$PATH"',
            "export TEST_BREW_LOADED=1",
        ]
        executable(brew_bin / "brew", '#!/bin/sh\n'
                   '[ "$1" = shellenv ] && [ "$2" = sh ] || exit 1\n'
                   '[ "${TEST_SHELLENV_FAIL:-0}" != 1 ] || exit 7\n'
                   + "printf '%s\\n' " + " ".join(map(shlex.quote, exports)) + "\n")
        for tool in ("delta", "nvim"):
            executable(brew_bin / tool, "#!/bin/sh\nexit 0\n")
        log = self.temporary / "calls.jsonl"
        self.env.update(TEST_PREFIX=str(prefix), TEST_CALLS=str(log))
        executable(self.bin / "chezmoi", "#!" + sys.executable + "\n" + '''
import json
import os
from pathlib import Path
import shutil
import sys

args = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[0] == "execute-template":
    print(os.environ["TEST_PREFIX"])
elif args[0] == "init" and "--apply" in args:
    sys.exit(int(os.environ.get("TEST_APPLY_STATUS", "0")))
elif args[0] == "init":
    assert os.environ.get("TEST_BREW_LOADED") == "1", "Homebrew shellenv was not inherited"
    for tool in ("delta", "nvim"):
        assert shutil.which(tool) == str(Path(os.environ["TEST_PREFIX"]) / "bin" / tool), tool
else:
    sys.exit("unexpected chezmoi command: " + str(args))
''')
        return log

    def test_installer_refreshes_config_with_homebrew_on_path(self):
        log = self.installer_fixture()
        result = self.run_command(["sh", str(SOURCE / "install.sh"), "--branch", "bootstrap"])
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(calls, [
            ["init", "--apply", "--branch", "bootstrap", "seven7thirty3five5"],
            ["execute-template", '{{ includeTemplate "brew-prefix" . }}'],
            ["init", "--branch", "bootstrap"],
        ])
        self.assertIn("Done.", result.stdout)

    def test_installer_stops_after_failure(self):
        for overrides, expected in (
            ({"TEST_APPLY_STATUS": "9"}, 9),
            ({"TEST_PREFIX": ""}, 1),
            ({"TEST_SHELLENV_FAIL": "1"}, 7),
        ):
            with self.subTest(overrides=overrides):
                log = self.installer_fixture()
                self.env.update(overrides)
                result = self.run_command(["sh", str(SOURCE / "install.sh")])
                self.assertEqual(result.returncode, expected, result.stderr)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                self.assertFalse(any(call == ["init"] for call in calls))
                self.assertNotIn("Done.", result.stdout)
                shutil.rmtree(self.temporary / "mock homebrew")
                log.unlink()
                for name in ("TEST_APPLY_STATUS", "TEST_SHELLENV_FAIL"):
                    self.env.pop(name, None)


if __name__ == "__main__":
    unittest.main()
