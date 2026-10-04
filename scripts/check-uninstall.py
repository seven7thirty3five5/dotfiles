#!/usr/bin/env python3
"""Exercise teardown in temporary homes; guard every destructive system command."""

import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]

MOCK = r'''
import json
import os
from pathlib import Path
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
state_path = Path(os.environ["TEST_STATE"])
state = json.loads(state_path.read_text())
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
def save():
    state_path.write_text(json.dumps(state))
if name in ("rm", "rmdir"):
    for path in [arg for arg in args if not arg.startswith("-")]:
        assert path.startswith(os.environ["TEST_ROOT"] + "/") or path.startswith("/tmp/dotfiles-uninstall."), path
    sys.exit(subprocess.call(["/bin/" + name, *args]))
elif name == "uname":
    print(state["platform"])
elif name == "id":
    print("tester" if args == ["-un"] else "501")
elif name == "getent":
    print("tester:x:501:501::" + os.environ["HOME"] + ":" + state["shell"])
elif name == "dscl":
    print("UserShell: " + state["shell"])
elif name == "chsh":
    state["shell"] = args[args.index("-s") + 1]
    save()
elif name == "sudo":
    if args[0] not in ("-v", "-n"):
        sys.exit(subprocess.call(args))
elif name == "brew":
    if args == ["list", "--cask"]:
        print("\n".join(state["casks"]))
    elif "uninstall" in args:
        assert Path(os.environ["TEST_PREFIX"]).exists(), "Casks must be uninstalled before Homebrew"
        state["casks"].remove(args[-1])
        save()
elif name == "gh":
    assert not any(key in os.environ for key in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"))
    assert args[:2] == ["auth", "logout"], "No network queries are needed"
elif name == "chezmoi":
    assert "managed" in args
    print(Path(os.environ["HOME"]) / "tracked-from-live-query")
elif name == "xcode-select":
    if args == ["--print-path"] and state["sdk"]:
        print(os.environ["TEST_SDK"])
    elif args == ["--reset"]:
        state["sdk"] = False
        save()
    else:
        sys.exit(1)
elif name == "pkgutil":
    if args == ["--pkgs"]:
        print("\n".join(state["receipts"]))
    else:
        state["receipts"].remove(args[-1])
        save()
elif name == "security":
    service = args[-1]
    if service not in state["credentials"]:
        sys.exit(1)
    if args[0] == "delete-generic-password":
        state["credentials"].remove(service)
        save()
elif name in ("dpkg-query", "rpm"):
    for package in state["packages"]:
        print(package + ("\tinstalled" if name == "dpkg-query" else ""))
elif name == "dnf":
    if "list" in args:
        if state.get("group"):
            print("Development Tools (development-tools)")
    elif "group" in args:
        state["group"] = False
        save()
    elif "remove" in args:
        state["packages"] = [package for package in state["packages"] if package not in args]
        save()
elif name == "apt-get":
    if state["package_failure"]:
        sys.exit(8)
    state["packages"] = [package for package in state["packages"] if package not in args]
    save()
elif name in ("launchctl", "systemctl"):
    pass
else:
    sys.exit("unexpected command: " + name)
'''


class UninstallChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-teardown-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands.jsonl"
        self.log.touch()
        self.state_path = self.root / "commands-state.json"
        self.state = dict(platform="Linux", shell="/bin/bash", packages=[], package_failure=False,
                          casks=[], receipts=[], sdk=False, credentials=[])
        self.state_path.write_text(json.dumps(self.state))
        self.env = dict(HOME=str(self.home), PATH=str(self.bin) + os.pathsep + os.defpath,
                        LC_ALL="C", TEST_ROOT=str(self.root), TEST_STATE=str(self.state_path),
                        TEST_LOG=str(self.log))
        for name in ("rm", "rmdir", "uname", "id", "getent", "dscl", "chsh", "sudo",
                     "brew", "gh", "chezmoi", "xcode-select", "pkgutil", "security",
                     "dpkg-query", "apt-get", "rpm", "dnf", "launchctl", "systemctl"):
            path = self.bin / name
            path.write_text("#!" + sys.executable + "\n" + MOCK)
            path.chmod(0o755)
        # Redirect only absolute system paths. User Library paths stay under HOME.
        text = (SOURCE / "uninstall.sh").read_text()
        for system in ("/opt/homebrew", "/home/linuxbrew", "/Library", "/Applications", "/etc"):
            text = re.sub(r"(?<!\$uninstall_home)" + re.escape(system),
                          str(self.root / "system") + system, text)
        text = re.sub(r"/usr/bin/sudo\b|/bin/rmdir\b|/bin/rm\b",
                      lambda match: shlex.quote(str(self.bin / Path(match[0]).name)), text)
        self.script = self.root / "uninstall.sh"
        self.script.write_text(text)
        self.inventory = self.home / ".local/state/dotfiles-bootstrap"
        self.inventory.mkdir(parents=True)
        (self.inventory / "prerequisites-manager").write_text("none\n")
        self.prefix = self.home / ".brew"
        self.env["TEST_PREFIX"] = str(self.prefix)

    def update_state(self, **changes):
        state = json.loads(self.state_path.read_text())
        state.update(changes)
        self.state_path.write_text(json.dumps(state))

    def artifact(self, relative, text="test data"):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def run_uninstall(self, *args, original=False):
        return subprocess.run(["sh", str(SOURCE / "uninstall.sh" if original else self.script), *args],
                              cwd=self.root, env=self.env, capture_output=True, text=True, timeout=30)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def populate(self):
        artifacts = [".zshenv", ".hushlogin", ".editorconfig", ".zsh_history", ".zsh_sessions/session",
                     ".config/gh/hosts.yml", ".config/nvim/init.lua", ".config/zsh/.zshrc.local",
                     ".local/share/nvim/lazy/plugin", ".local/share/nvim/mason/bin/server",
                     ".local/share/atuin/history.db", ".local/share/zoxide/db.zo",
                     ".local/share/gh/extensions/gh-dash/gh-dash", ".local/state/nvim/log",
                     ".local/state/zsh/history", ".cache/zsh/zcompdump", ".cache/chezmoi/theme",
                     "Library/Caches/Homebrew/download", "Library/Logs/Homebrew/log",
                     ".local/bin/chezmoi", ".local/share/chezmoi/.chezmoiroot", "previously-managed"]
        for relative in artifacts:
            self.artifact(relative)
        self.artifact(".config/gh/hosts.yml", "github.com:\n    user: tester\n    users:\n        tester:\n        second-user:\n")
        (self.inventory / "managed-files").write_text(
            str(self.home / "previously-managed") + "\n" + str(self.home / "tracked-from-live-query") + "\n")
        self.artifact("tracked-from-live-query")
        brew = self.artifact(".brew/bin/brew", (self.bin / "brew").read_text())
        brew.chmod(0o755)
        gh = self.artifact(".brew/bin/gh", (self.bin / "gh").read_text())
        gh.chmod(0o755)
        self.artifact(".config/nvim/lazy-lock.json").unlink()
        (self.home / ".config/nvim/lazy-lock.json").symlink_to(self.home / ".local/share/chezmoi/lock.json")
        return [self.home / relative for relative in artifacts] + [self.prefix, self.home / "tracked-from-live-query"]

    def test_full_teardown_without_binaries_and_repeat(self):
        artifacts = self.populate()
        unrelated = self.artifact(".config/unrelated/keep")
        # Missing Homebrew/chezmoi must not prevent complete cleanup.
        (self.prefix / "bin/brew").unlink()
        (self.bin / "chezmoi").unlink()
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        for artifact in artifacts + [self.inventory]:
            self.assertFalse(artifact.exists() or artifact.is_symlink(), str(artifact))
        self.assertTrue(unrelated.exists())
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Already uninstalled.", result.stdout)

    def test_dry_run_does_not_remove_or_modify(self):
        artifacts = self.populate()
        self.update_state(shell="/home/tester/.brew/bin/zsh")
        result = self.run_uninstall("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(artifact.exists() for artifact in artifacts))
        self.assertIn("/bin/bash", result.stdout)
        self.assertFalse(any(call[0] in ("chsh", "sudo", "apt-get")
                             for call in self.calls()))
        self.assertFalse(any(call[0] == "gh" for call in self.calls()))

    def test_can_remove_its_own_repository(self):
        self.populate()
        deployed_script = self.home / ".local/share/chezmoi/uninstall.sh"
        deployed_script.write_text(self.script.read_text())
        self.script = deployed_script
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Uninstalled.", result.stdout)
        self.assertFalse(deployed_script.exists())

    def test_recorded_custom_paths_are_removed(self):
        state_file = self.artifact("custom/chezmoi-state.boltdb")
        plugin = self.artifact("custom/gh-data/extensions/gh-dash")
        tracked = self.artifact("custom/config/nvim/init.lua")
        (self.inventory / "persistent-state").write_text(str(state_file))
        (self.inventory / "path-GH_DATA_DIR").write_text(str(plugin.parents[1]))
        (self.inventory / "xdg-config").write_text(str(self.home / "custom/config"))
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(state_file.exists() or plugin.exists() or tracked.exists())

    def test_linux_switches_to_bash_before_removing_prefix(self):
        self.populate()
        self.update_state(shell=str(self.prefix / "bin/zsh"))
        self.env.update(GH_TOKEN="fixture-token", GITHUB_TOKEN="fixture-token",
                        GH_ENTERPRISE_TOKEN="fixture-token", GITHUB_ENTERPRISE_TOKEN="fixture-token")
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        changed = next(i for i, call in enumerate(calls) if call[:3] == ["chsh", "-s", "/bin/bash"])
        removed = next(i for i, call in enumerate(calls) if call[0] == "rm" and str(self.prefix) in call)
        self.assertLess(changed, removed)
        accounts = [call[-1] for call in calls if call[0] == "gh"]
        self.assertEqual(sorted(accounts), ["second-user", "tester"])

    def test_symlink_targets_are_preserved(self):
        external = self.root / "other-user"
        external.mkdir()
        sentinel = external / "keep"
        sentinel.write_text("keep")
        (self.home / ".config").mkdir()
        (self.home / ".config/nvim").symlink_to(external)
        (self.inventory / "managed-files").write_text(str(self.home / ".config/nvim/keep") + "\n")
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(sentinel.exists())
        self.assertFalse((self.home / ".config/nvim").is_symlink())

    def test_invalid_paths_fail_before_cleanup(self):
        sentinel = self.artifact(".zshenv")
        for target in ("/", str(self.home), str(self.home / "../outside"), str(self.home / ".local")):
            with self.subTest(target=target):
                (self.inventory / "managed-files").write_text(target + "\n")
                result = self.run_uninstall("--yes")
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(sentinel.exists())
        (self.inventory / "managed-files").unlink()
        self.env["XDG_CONFIG_HOME"] = str(self.root / "outside-home")
        result = self.run_uninstall("--yes")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(sentinel.exists())

    def test_macos_rejects_custom_prefix(self):
        self.update_state(platform="Darwin", shell="/bin/zsh")
        result = self.run_uninstall("--dry-run", "--prefix", str(self.home / ".brew"), original=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("macOS supports only /opt/homebrew", result.stderr)

    def test_macos_removes_sdk_app_receipts_and_keychain(self):
        self.update_state(platform="Darwin", shell="/bin/zsh", sdk=True, casks=["ghostty", "another-app"],
                          receipts=["com.apple.pkg.CLTools_Executables"], credentials=["gh:github.com"])
        prefix = self.root / "system/opt/homebrew"
        (prefix / "bin").mkdir(parents=True)
        for name in ("brew", "gh"):
            path = prefix / "bin" / name
            path.write_text((self.bin / name).read_text())
            path.chmod(0o755)
        sdk = self.root / "system/Library/Developer/CommandLineTools"
        app = self.root / "system/Applications/Ghostty.app"
        sdk.mkdir(parents=True)
        app.mkdir(parents=True)
        self.env.update(TEST_SDK=str(sdk), TEST_PREFIX=str(prefix))
        self.artifact("Library/Preferences/com.mitchellh.ghostty.plist")
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(prefix.exists() or sdk.exists() or app.exists())
        state = json.loads(self.state_path.read_text())
        self.assertEqual(state["shell"], "/bin/zsh")
        self.assertEqual(state["receipts"], [])
        self.assertEqual(state["credentials"], [])
        self.assertFalse(state["sdk"])
        self.assertFalse(any(call[:2] == ["brew", "uninstall"] and call[-1] == "ghostty" for call in self.calls()))

    def test_package_failure_keeps_inventory_for_retry(self):
        self.populate()
        self.update_state(packages=["existing", "new-dependency"], package_failure=True)
        (self.inventory / "prerequisites-manager").write_text("apt\n")
        (self.inventory / "prerequisites-packages").write_text("new-dependency\nalready-removed\n")
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 8, result.stderr)
        self.assertTrue(self.inventory.exists())
        self.assertFalse(self.prefix.exists())
        self.update_state(package_failure=False)
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.state_path.read_text())["packages"], ["existing"])
        self.assertFalse(self.inventory.exists())
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Already uninstalled.", result.stdout)

    def test_legacy_prerequisites_are_removed_after_inventory_migration(self):
        self.update_state(packages=["existing", "curl", "build-essential"])
        (self.inventory / "legacy-prerequisites").write_text("apt\n")
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.state_path.read_text())["packages"], ["existing"])
        self.assertTrue(any(call[:3] == ["apt-get", "purge", "--auto-remove"] for call in self.calls()))

    def test_dnf_group_is_removed_once(self):
        self.update_state(packages=["new-dependency"], group=True)
        (self.inventory / "prerequisites-manager").write_text("dnf\n")
        (self.inventory / "prerequisites-packages").write_text("new-dependency\n")
        (self.inventory / "prerequisites-group").write_text("development-tools\n")
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads(self.state_path.read_text())
        self.assertFalse(state["group"])
        self.assertEqual(state["packages"], [])
        result = self.run_uninstall("--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Already uninstalled.", result.stdout)


if __name__ == "__main__":
    unittest.main()
