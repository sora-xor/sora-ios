#!/usr/bin/env python3
"""Generate public fixtures using the actual IrohaCrypto 0.2.6 implementation."""
import json
from pathlib import Path
import subprocess
from retarget_archive import retarget

p = Path(__file__).resolve().parent
old = p / 'IrohaCrypto-0.2.6'
assert subprocess.check_output(['git', '-C', str(old), 'rev-parse', 'HEAD'], text=True).strip() == '20010a2ad73471216927ec5d3341c2cdcb446c8c'
assert not subprocess.check_output(['git', '-C', str(old), 'status', '--porcelain'], text=True)
libraries = []
for source, name in [(old / 'IrohaCryptoImp/libed25519.a', '1x-ed25519'),
                     (old / 'libsodium-ios/lib/libsodium.a', '1x-sodium')]:
    destination = p / 'runtime' / name
    libraries.append(retarget(source, destination))
command = ['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-fobjc-arc', '-framework', 'Foundation', '-framework', 'Security',
           '-I' + str(old / 'IrohaCrypto/Classes'), '-I' + str(old / 'IrohaCryptoImp/include'), '-I' + str(old / 'libsodium-ios/include/sodium'),
           *map(str, (old / 'IrohaCrypto/Classes').glob('*.m')), str(p / 'generate_1x.m'), *map(str, libraries), '-o', str(p / 'runtime/generate_1x')]
(p / 'build-1x-command.json').write_text(json.dumps(command, indent=2) + '\n')
result = subprocess.run(command, capture_output=True, text=True)
(p / 'build-1x.log').write_text(result.stdout + result.stderr)
result.check_returncode()
result = subprocess.run([str(p / 'runtime/generate_1x')], capture_output=True, text=True, check=True)
(p / 'ios-1x-vectors.json').write_text(result.stdout)
data = json.loads(result.stdout)
assert data['upstreamKDFKnownAnswerPassed'] and len(data['vectors']) == 2
print('Two historical 1.x fixtures, signatures, phrase round trips, and upstream KDF known-answer passed.')
