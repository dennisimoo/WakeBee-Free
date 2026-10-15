#!/usr/bin/env python3
"""CI-only privileged install/authentication/removal check. Never renews a sleep lease."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SERVICE = 'io.github.dennisimoo.WakeBeeFree.helper'
INSTALLED = Path('/Library/PrivilegedHelperTools/io.github.dennisimoo.WakeBeeFree')
JOURNAL = f'/private/var/db/{SERVICE}/recovery.json'


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def main():
    if sys.platform != 'darwin' or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise SystemExit('This privileged smoke test runs only on a disposable GitHub macOS runner.')
    run('sudo', 'test', '!', '-e', JOURNAL)
    run('sudo', 'test', '!', '-e', INSTALLED)
    with tempfile.TemporaryDirectory() as temporary:
        app = Path(temporary) / "WakeBee Free 'probe'.app"
        shutil.copytree(ROOT / 'dist/WakeBee.app', app)
        executable = app / 'Contents/MacOS/WakeBee'
        manager = app / 'Contents/Resources/manage-helper.sh'
        uid = str(os.getuid())

        def compile_probe(rejected=False):
            command = ['xcrun', 'swiftc', '-module-name', 'WakeBeeHelperProtocol',
                       ROOT / 'Sources/WakeBeeHelperProtocol/HelperProtocol.swift',
                       ROOT / 'script/helper_probe.swift', '-o', executable]
            if rejected:
                command.extend(['-D', 'REJECTED'])
            run(*command)
            run('codesign', '--force', '--sign', '-', '--options', 'runtime,kill', app)

        compile_probe()
        try:
            run('sudo', '/bin/bash', manager, 'install', app, uid)
            installed = plistlib.loads((INSTALLED / 'client.plist').read_bytes())
            assert installed['uid'] == os.getuid()
            assert (INSTALLED / 'WakeBeeHelper').stat().st_uid == 0
            run(executable, timeout=15)  # Health only: never invokes pmset writes.
            # Same identifier and UID, different valid signature: must be denied.
            compile_probe(rejected=True)
            rejected = subprocess.run([str(executable)], timeout=15)
            assert rejected.returncode == 3, f'Expected XPC rejection, got {rejected.returncode}'
            # Updating the approved hash must make the new build work again.
            run('sudo', '/bin/bash', manager, 'install', app, uid)
            run(executable, timeout=15)
            # Restart exercises startup recovery with no journal or sleep lease.
            run('sudo', 'launchctl', 'kickstart', '-k', f'system/{SERVICE}')
            run(executable, timeout=15)
        finally:
            run('sudo', '/bin/bash', manager, 'uninstall', app, uid)
        assert not INSTALLED.exists()
        assert not Path(f'/Library/LaunchDaemons/{SERVICE}.plist').exists()
        run('sudo', 'test', '!', '-e', JOURNAL)
        print('Verified install, exact-build XPC acceptance/rejection, update, restart, and removal.')


if __name__ == '__main__':
    main()
