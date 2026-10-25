#!/usr/bin/env python3
"""Copy public-account database metadata after installation and compare retained identities privately."""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess

ROOT = Path(__file__).resolve().parent
BUILD = '2026091304'
SOURCE = 'f38dcd3002aeccd4d21f78b87fe8c7d5ee116ca6'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--install-directory', type=Path, required=True)
args = parser.parse_args()
installation = args.install_directory.resolve(strict=True)
assert installation.parent == ROOT / 'connected-wallet-diagnosis-20260913'
receipt_path = installation / 'observation.json'
receipt = json.loads(receipt_path.read_text())
assert receipt['build'] == BUILD and receipt['sourceRevision'] == SOURCE
assert receipt['status'] == 'installed-and-launched-awaiting-on-device-recovery'
assert receipt['noUninstall'] is True and receipt['preservedDatabaseIntegrityVerified'] is True
for label in ['preserve-documents', 'preserve-library', 'install', 'launch']:
    assert len([entry for entry in receipt['commands'] if entry['label'] == label and entry['exitCode'] == 0]) == 1
before = installation / 'before-install'
baselines = list(before.rglob('UserDataModel.sqlite'))
assert len(baselines) == 1, 'Retained baseline is missing or ambiguous'
baseline = baselines[0]
# Verify the preserved original bundle before opening disposable working copies.
baseline_hashes = {}
for suffix in ['', '-wal', '-shm']:
    path = Path(str(baseline) + suffix)
    if path.exists():
        relative = str(path.relative_to(before))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert receipt['preservedContainerHashes'].get(relative) == digest, 'Retained baseline changed'
        baseline_hashes[relative] = digest
os.umask(0o077)
output = installation / 'after-install-account-preservation'
output.mkdir(mode=0o700)
working_before = output / 'baseline-working-copy'
working_before.mkdir(mode=0o700)
for suffix in ['', '-wal', '-shm']:
    path = Path(str(baseline) + suffix)
    if path.exists(): shutil.copy2(path, working_before / path.name)
command = ['/usr/bin/xcrun', 'devicectl', 'device', 'copy', 'from',
    '--device', 'E91E0F25-96F2-5CB6-A7CC-EB3435002556',
    '--domain-type', 'appDataContainer', '--domain-identifier', 'co.jp.soramitsu.sora',
    '--source', 'Documents/CoreData', '--destination', str(output / 'CoreData'),
    '--json-output', str(output / 'copy.json')]
with (output / 'copy.log').open('w') as log:
    subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
after = list((output / 'CoreData').rglob('UserDataModel.sqlite'))
assert len(after) == 1, 'Current database is missing or ambiguous'

def read_identities(database_path):
    with sqlite3.connect(database_path.as_uri() + '?mode=ro', uri=True) as connection:
        connection.execute('PRAGMA query_only=ON')
        assert connection.execute('PRAGMA quick_check').fetchall() == [('ok',)], 'Copied database integrity failed'
        rows = connection.execute('SELECT ZIDENTIFIER,ZPUBLICKEY,ZCRYPTOTYPE,ZNETWORKTYPE FROM ZCDACCOUNTITEM LIMIT 4097').fetchall()
        assert 1 <= len(rows) <= 4096, 'Unexpected retained account count'
        assert all(isinstance(row[0], str) and isinstance(row[1], bytes) and
                   type(row[2]) is int and type(row[3]) is int for row in rows), 'Invalid account metadata'
        assert len({row[0] for row in rows}) == len(rows), 'Duplicate retained account identities'
        return Counter(rows)

old = read_identities(working_before / baseline.name)
new = read_identities(after[0])
assert old == new, 'Retained account identities changed; inspect private evidence locally'
assert all(hashlib.sha256((before / path).read_bytes()).hexdigest() == digest
           for path, digest in baseline_hashes.items()), 'Baseline was modified during comparison'
safe = {'status': 'retained-account-identities-unchanged', 'build': BUILD,
    'sourceRevision': SOURCE, 'accountCount': sum(old.values()), 'databaseIntegrity': 'passed',
    'comparedFields': ['address', 'publicKey', 'cryptoType', 'networkType'],
    'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'secretsQueried': False, 'originalBaselinePreserved': True,
    'installReceiptSha256': hashlib.sha256(receipt_path.read_bytes()).hexdigest()}
(output / 'safe-observation.json').write_text(json.dumps(safe, indent=2) + '\n')
print(json.dumps(safe, indent=2))
