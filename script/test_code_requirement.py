"""Exercise actual ad-hoc signing and tamper rejection, without changing sleep."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('code_requirement.sh')


@unittest.skipUnless(sys.platform == 'darwin', 'requires Apple codesign and Mach-O tools')
class CodeRequirementTests(unittest.TestCase):
    def test_universal_hash_requirement_accepts_both_arches_and_rejects_other_code(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / 'probe.c'
            source.write_text('int main(void) { return 0; }\n')
            binary = directory / 'probe'
            subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-arch', 'x86_64',
                            str(source), '-o', str(binary)], check=True)
            subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime,kill', str(binary)], check=True)
            requirement = subprocess.check_output(['/bin/bash', str(SCRIPT), str(binary)], text=True).strip()
            for architecture in ['arm64', 'x86_64']:
                subprocess.run(['codesign', '--verify', '--strict', '--arch', architecture,
                                '-R', '=' + requirement, str(binary)], check=True)
            # A different, validly ad-hoc signed executable cannot impersonate it.
            source.write_text('int main(void) { return 1; }\n')
            other = directory / 'other'
            subprocess.run(['xcrun', 'clang', str(source), '-o', str(other)], check=True)
            subprocess.run(['codesign', '--force', '--sign', '-', str(other)], check=True)
            self.assertNotEqual(subprocess.run(['codesign', '--verify', '-R', '=' + requirement, str(other)],
                                               capture_output=True).returncode, 0)
            # Modify a signed page, rather than trailing signature padding.
            thin = directory / 'thin'
            subprocess.run(['lipo', str(binary), '-thin', 'arm64', '-output', str(thin)], check=True)
            subprocess.run(['codesign', '--verify', '--strict', '-R', '=' + requirement, str(thin)], check=True)
            content = bytearray(thin.read_bytes())
            content[4096] ^= 1
            thin.write_bytes(content)
            self.assertNotEqual(subprocess.run(['codesign', '--verify', '--strict',
                                                '-R', '=' + requirement, str(thin)], capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main()
