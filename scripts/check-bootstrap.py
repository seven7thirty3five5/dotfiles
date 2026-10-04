#!/usr/bin/env python3
"""Test the setup scripts' decisions without installing anything.

What this tests
---------------
install.sh and the script that installs Homebrew
(home/.chezmoiscripts/run_once_before_10-install-homebrew.sh.tmpl) are hard to
test for real: they download and install software, need sudo, and behave
differently on macOS and Linux. So these tests swap the programs those scripts
call (curl, sudo, uname, brew and chezmoi) for "stubs": tiny fake programs that
only give a made-up answer or write down how they were called. The tests check:

  - which folders Homebrew may be installed in, on macOS and on Linux;
  - that every script in home/.chezmoiscripts is valid shell code, both as
    chezmoi writes it for macOS and as it writes it for Linux;
  - that on macOS, the Homebrew script reuses an existing Homebrew, refuses
    Intel Macs and users without sudo, and otherwise installs into /opt/homebrew;
  - that install.sh runs its three chezmoi commands in order, with Homebrew's
    programs on PATH for the last one, and stops as soon as a step fails.

The real installation is tested on fresh machines by the Bootstrap workflow
(.github/workflows/bootstrap.yml). These tests are much quicker, and can try
failures that are hard to arrange on a real machine, like an Intel Mac.

How it works
------------
It uses unittest, the testing framework built into Python. Each method below
whose name starts with test_ is one test, and unittest runs setUp() before each
one, so every test starts with its own empty temporary folder. Each
self.assert...() call checks one thing: if it's false, the test fails and shows
the message given, often the error output of the command being tested. Inside a
`with self.subTest(...)` block, each case is reported on its own, so one failing
case doesn't hide the others.

Run it with:  python3 scripts/check-bootstrap.py   (add -v to list each test)
It needs chezmoi installed. It ends with OK, or with details of each failure
(exit status 1). GitHub runs it on macOS and Linux for every push
(.github/workflows/shell-checks.yml).
"""

# Python's standard library only, so there is nothing to install.
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


# The repository folder (this file is scripts/check-bootstrap.py), and home/,
# the folder named in .chezmoiroot that holds the dotfiles.
SOURCE = Path(__file__).resolve().parents[1]
STATE = SOURCE / (SOURCE / ".chezmoiroot").read_text().strip()


def executable(path, content):
    """Write a small program, usually a shell script, and make it runnable.

    The program's first line, such as #!/bin/sh, names the program that runs it.
    Mode 0o755 lets you read, change and run the file, and anyone else read and
    run it.
    """

    # About the Python text these programs are written from: \n is a line break
    # in the file, and \\n puts the two characters \n in the file, which the
    # program itself (printf, for example) turns into a line break when it runs.
    path.write_text(content)
    path.chmod(0o755)


class BootstrapChecks(unittest.TestCase):
    def setUp(self):
        """Before each test: a new temporary folder, home folder and environment."""

        # The folder is deleted after the test (addCleanup), even if the test fails.
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-")
        self.addCleanup(self.directory.cleanup)
        self.temporary = Path(self.directory.name)

        # A pretend home folder. The space in its name catches any place in the
        # scripts that forgets to put quotes around a path.
        self.home = self.temporary / "home with spaces"
        self.home.mkdir()

        # The folder for the tests' fake programs. It comes first on PATH, so the
        # scripts find a fake program before a real one with the same name.
        self.bin = self.temporary / "bin"
        self.bin.mkdir()

        # The environment variables for every command, starting from almost
        # nothing so that no settings from this computer leak in. os.defpath is a
        # basic system PATH (such as /bin:/usr/bin), for standard commands like
        # sh; os.pathsep is the ":" between PATH's folders. LC_ALL=C keeps
        # messages in plain English, the same everywhere.
        self.env = {
            "HOME": str(self.home),
            "PATH": str(self.bin) + os.pathsep + os.defpath,
            "TMPDIR": str(self.temporary),
            "LC_ALL": "C",
        }

    def run_command(self, command, input=None):
        """Run a command in the test environment, inside the pretend home folder.

        input is text sent to the command as if it were typed in; the tests use
        it to hand a script to `sh`, which runs what it reads. This doesn't stop
        when the command fails, because some tests expect a failure: it returns
        the exit status (returncode), output (stdout) and error output (stderr)
        for the test to check. timeout=30 stops a command that hangs.
        """

        return subprocess.run(
            command, input=input, env=self.env, cwd=self.home,
            text=True, capture_output=True, timeout=30,
        )

    def render(self, template, system):
        """Fill in a chezmoi template as `system` would, and return the result.

        `chezmoi execute-template TEXT` fills in the template parts of TEXT (the
        parts between double braces) and prints the result. The templates pick
        their macOS or Linux parts by reading .chezmoi.os, the operating system
        chezmoi detected. To fill in the macOS version on Linux, and the other
        way around, this wraps the template in

            {{ with dict "chezmoi" (dict "os" ... "homeDir" ... "sourceDir" ...) }}
            the template
            {{ end }}

        Inside `with`, the data the template reads (its "dot") is swapped for
        this made-up data. So .chezmoi.os is `system` ("darwin", which is what
        chezmoi calls macOS, or "linux"), .chezmoi.homeDir is the pretend home
        folder, and .chezmoi.sourceDir is the repository's home/ folder. Those
        are the only .chezmoi values the tested templates read; if one ever reads
        another, chezmoi stops with an error instead of guessing. json.dumps()
        writes each value in quotes, the same way templates write text.
        """

        chezmoi = shutil.which("chezmoi")
        self.assertIsNotNone(chezmoi, "chezmoi is required")

        # chezmoi's settings: a file made for this test, never yours. Automatic
        # commit and push are off, as a precaution.
        config = self.temporary / "chezmoi.toml"
        config.write_text('[git]\nautoCommit = false\nautoPush = false\n')
        context = (
            '{{ with dict "chezmoi" (dict "os" '
            + json.dumps(system) + ' "homeDir" '
            + json.dumps(str(self.home)) + ' "sourceDir" '
            + json.dumps(str(STATE)) + ') }}'
        )

        # --source: this repository. --destination: the pretend home folder.
        # --config, --cache and --persistent-state: chezmoi's settings, download
        # cache and record of what it has done, all temporary. --no-tty: never
        # stop to ask a question. --no-pager: print directly, not through `less`.
        result = self.run_command([
            chezmoi, "--source", str(SOURCE), "--destination", str(self.home),
            "--config", str(config), "--cache", str(self.temporary / "cache"),
            "--persistent-state", str(self.temporary / "state.boltdb"),
            "--no-tty", "--no-pager", "execute-template",
            context + template + "{{ end }}",
        ])

        # If chezmoi failed, fail the test and show chezmoi's error message.
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_supported_prefixes(self):
        """The Homebrew folders allowed on each system, in order of preference.

        macOS: only /opt/homebrew. Linux: the default /home/linuxbrew/.linuxbrew
        (creating it needs sudo), then ~/.linuxbrew and ~/.brew (no sudo needed).
        """

        template = '{{ includeTemplate "brew-prefixes" . }}'
        self.assertEqual(self.render(template, "darwin").splitlines(), ["/opt/homebrew"])
        self.assertEqual(self.render(template, "linux").splitlines(), [
            "/home/linuxbrew/.linuxbrew",
            str(self.home / ".linuxbrew"), str(self.home / ".brew"),
        ])

    def test_install_script_syntax(self):
        """Every setup script is valid shell code, filled in for macOS and for Linux.

        `sh -n` reads a script and reports syntax errors without running any of it.
        """

        for system in ("darwin", "linux"):
            for script in sorted((STATE / ".chezmoiscripts").glob("*.tmpl")):
                with self.subTest(system=system, script=script.name):
                    result = self.run_command(["sh", "-n"], self.render(script.read_text(), system))
                    self.assertEqual(result.returncode, 0, result.stderr)

    def test_macos_install_requires_sudo_and_uses_default_prefix(self):
        """On macOS, the Homebrew script reuses, refuses, or installs into /opt/homebrew.

        It runs the script, filled in for macOS, with three fake programs:

          uname  prints $TEST_ARCH: arm64 (Apple silicon) or x86_64 (Intel);
          sudo   succeeds if $TEST_SUDO is yes, and otherwise fails with the
                 message the real sudo prints for a user who isn't an
                 administrator;
          curl   returns a one-line fake installer instead of downloading
                 Homebrew's real one. It only writes down how it was run.
        """

        executable(self.bin / "uname", '#!/bin/sh\nprintf "%s\\n" "$TEST_ARCH"\n')
        sudo = self.bin / "sudo"
        executable(sudo, '#!/bin/sh\n[ "$TEST_SUDO" = yes ] && exit 0\n'
                   'echo "tester is not in the sudoers file" >&2\nexit 1\n')

        # The fake installer writes "<number of arguments>:<$NONINTERACTIVE>" to
        # this log file. If the file exists, the installer ran. "0:1" means it got
        # no arguments, so no --path for a custom folder (it uses the default,
        # /opt/homebrew), and NONINTERACTIVE=1, so it asks no questions.
        log = self.temporary / "install-log"
        self.env["TEST_INSTALL_LOG"] = str(log)
        installer = 'printf "%s:%s\\n" "$#" "$NONINTERACTIVE" > "$TEST_INSTALL_LOG"\n'
        executable(self.bin / "curl", "#!/bin/sh\nprintf '%s' " + shlex.quote(installer) + "\n")
        template = (STATE / ".chezmoiscripts/run_once_before_10-install-homebrew.sh.tmpl").read_text()

        # Change two things in the script itself, so that it never finds this
        # computer's Homebrew or uses its sudo: the line that looks for an
        # existing Homebrew becomes `brew=` (none found), and /usr/bin/sudo
        # becomes the fake sudo. The script calls sudo by its full path, as
        # Homebrew's installer does, so a fake sudo on PATH alone wouldn't be used.
        template = template.replace('{{ template "find-brew.sh" . }}', "brew=\n")
        script = self.render(template, "darwin").replace("/usr/bin/sudo", shlex.quote(str(sudo)))

        # Case 1: Homebrew is already installed. The script must finish
        # successfully right away: no sudo needed, no installer run. (`sh` with
        # no file name runs the script it's given as input.)
        self.env.update(TEST_ARCH="arm64", TEST_SUDO="no")
        existing = script.replace("brew=\n", "brew=/opt/homebrew/bin/brew\n")
        result = self.run_command(["sh"], existing)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(log.exists(), "An existing macOS installation must be reused without sudo")

        # Cases 2 to 4: no Homebrew yet. Each row: the processor, whether the
        # user has sudo, the exit status the script must end with, and text its
        # error output must contain ("" means any: all text contains "").
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

                # A refusal must come before the installer runs. A success must
                # run the installer for the default folder.
                if expected:
                    self.assertFalse(log.exists(), "Homebrew ran before its prerequisites passed")
                else:
                    self.assertEqual(log.read_text(), "0:1\n", "macOS must use the default prefix")

    def installer_fixture(self):
        """Set up fakes for testing install.sh, and return the chezmoi call log.

        (A "fixture" is the setup a test needs.) install.sh runs chezmoi, and
        then Homebrew's brew, so this makes fake versions of both:

          - A pretend Homebrew folder, "mock homebrew". Its bin/brew only answers
            `brew shellenv sh`, and fails if run any other way. It prints
            `export` lines that put its bin folder on PATH and set
            TEST_BREW_LOADED=1, or fails with exit status 7 if
            TEST_SHELLENV_FAIL is 1. Its bin folder also holds fake delta and
            nvim programs that do nothing.
          - A fake chezmoi, written in Python, in the folder that comes first on
            PATH, so install.sh uses it instead of downloading the real one. It
            adds each call's arguments to the log, one JSON list per line, then:

              init --apply      succeeds, or exits with $TEST_APPLY_STATUS to
                                pretend that applying the dotfiles failed;
              execute-template  prints $TEST_PREFIX: where it "found" Homebrew;
              init              checks that install.sh loaded Homebrew first:
                                TEST_BREW_LOADED is 1, and delta and nvim are
                                found in the pretend Homebrew. If not, `assert`
                                stops it with an error, which makes install.sh,
                                and so the test, fail;
              anything else     fails, since install.sh shouldn't run it.
        """

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

        # The fake chezmoi's first line names the Python running these tests
        # (sys.executable), which then runs the program below.
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
        """install.sh runs chezmoi three times, in order, then reports success.

        Extra arguments given to install.sh (here --branch bootstrap) must reach
        both `chezmoi init` calls. The fake chezmoi itself checks that Homebrew's
        programs were on PATH for the last call.
        """

        log = self.installer_fixture()
        result = self.run_command(["sh", str(SOURCE / "install.sh"), "--branch", "bootstrap"])
        self.assertEqual(result.returncode, 0, result.stderr)

        # Read the log back: one list of arguments per chezmoi call.
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(calls, [
            # 1. Download the repository and apply the dotfiles.
            ["init", "--apply", "--use-builtin-git=true", "--branch", "bootstrap", "seven7thirty3five5"],

            # 2. Ask where Homebrew was installed.
            ["execute-template", '{{ includeTemplate "brew-prefix" . }}'],

            # 3. Refresh chezmoi's settings, now that delta and nvim exist.
            ["init", "--branch", "bootstrap"],
        ])
        self.assertIn("Done.", result.stdout)

    def test_installer_stops_after_failure(self):
        """install.sh stops at the first failure, with that failure's exit status.

        Three things can fail: applying the dotfiles (status 9 here), finding
        Homebrew afterwards (install.sh's own error, status 1), or
        `brew shellenv` (status 7 here; install.sh saves brew's output in a
        variable before running it so that this failure isn't missed). In each
        case the last `chezmoi init` must not run, and "Done." must not appear.
        """

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

                # With no extra arguments, the last call would be just ["init"].
                self.assertFalse(any(call == ["init"] for call in calls))
                self.assertNotIn("Done.", result.stdout)

                # Remove the fakes and the log so the next case starts fresh.
                # installer_fixture() creates them again and resets TEST_PREFIX,
                # so only the other two overrides need removing.
                shutil.rmtree(self.temporary / "mock homebrew")
                log.unlink()
                for name in ("TEST_APPLY_STATUS", "TEST_SHELLENV_FAIL"):
                    self.env.pop(name, None)


# Run all the tests when this file is run as a program. unittest ends with a
# summary: OK, or the details of each failure and exit status 1.
if __name__ == "__main__":
    unittest.main()
