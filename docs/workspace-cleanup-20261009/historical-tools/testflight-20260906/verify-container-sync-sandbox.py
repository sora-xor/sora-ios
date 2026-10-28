#!/usr/bin/env python3
"""Compare the published and corrected Swift ancestor helpers under macOS sandbox denial."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
output = root / 'startup-container-sandbox-proof'
output.mkdir(mode=0o700, exist_ok=False)
home = output / 'FixtureContainer'
directory = home / 'Documents/CoreData'
directory.mkdir(parents=True)

def method(source, name):
    start = source.index('    private static func ' + name) if '    private static func ' + name in source else source.index('    static func ' + name)
    # Signatures may contain a closure default; locate the throwing function body.
    body = source.index(') throws {', start) + len(') throws ')
    depth = 0
    for index in range(body, len(source)):
        if source[index] == '{':
            depth += 1
        elif source[index] == '}':
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise AssertionError('Missing method end')

path = 'SoraPassport/Common/Model/WalletNetworkModel.swift'
sources = {
    'published': root / 'publish-2026090706-ios' / path,
    'corrected': root / 'startup-recovery-ios' / path,
}
segments = ['import Foundation\nimport Darwin\n']
hashes = {}
for label, source_path in sources.items():
    text = source_path.read_text()
    ancestor = method(text, 'synchronizeAncestorDirectoryEntries')
    sync = method(text, 'synchronize')
    hashes[label] = hashlib.sha256(ancestor.encode()).hexdigest()
    arguments = 'from: descriptor, maximumDepth: 4'
    if label == 'corrected':
        arguments += ', containerURL: URL(fileURLWithPath: home, isDirectory: true)'
    segments.append('enum ' + label.title() + ' {\n'
        'enum Failure: Error { case invalidTarget, fileSystemFailure }\n'
        + ancestor + '\n' + sync + '\n'
        'static func run(_ descriptor: Int32, home: String) throws {\n'
        'try synchronizeAncestorDirectoryEntries(' + arguments + ')\n}\n}\n')
segments.append('''
let arguments = CommandLine.arguments
let descriptor = Darwin.open(arguments[2], O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
guard descriptor >= 0 else { fatalError("Fixture directory unavailable") }
defer { _ = Darwin.close(descriptor) }
do {
    if arguments[1] == "published" {
        try Published.run(descriptor, home: arguments[3])
    } else {
        try Corrected.run(descriptor, home: arguments[3])
    }
    print("ancestor_sync_succeeded")
} catch {
    print("ancestor_sync_failed")
    exit(2)
}
''')
swift = output / 'ContainerSyncProof.swift'
swift.write_text(''.join(segments))
binary = output / 'ContainerSyncProof'
subprocess.run(['/usr/bin/xcrun', 'swiftc', str(swift), '-o', str(binary)], check=True)
# Deny reading only the fixture container's parent; system libraries and all
# content inside the fixture container remain accessible. No system setting changes.
profile = '(version 1) (allow default) (deny file-read-data (literal ' + json.dumps(str(output.resolve())) + '))'
results = {}
for label in sources:
    command = ['/usr/bin/sandbox-exec', '-p', profile, str(binary), label,
               str(directory), str(home)]
    result = subprocess.run(command, text=True, capture_output=True)
    results[label] = {'exitCode': result.returncode, 'output': result.stdout.strip(),
                      'error': result.stderr.strip(), 'helperSHA256': hashes[label]}
record = {'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'sourceBuild': '2026090706', 'scope': 'Exact Swift ancestor method; macOS kernel sandbox denial of fixture container parent',
          'fixtureContainer': str(home), 'deniedParent': str(output), 'results': results,
          'reportedIPhoneRecoveryVerified': False}
(output / 'observation.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
assert results['published']['exitCode'] == 2, results
assert results['corrected']['exitCode'] == 0, results
