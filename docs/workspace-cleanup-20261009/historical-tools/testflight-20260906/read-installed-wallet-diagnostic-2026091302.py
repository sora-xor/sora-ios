#!/usr/bin/env python3
"""Read only the fixed diagnostic fields after the verified in-place install."""
import argparse
import datetime
import json
import math
import os
from pathlib import Path
import plistlib
import subprocess
import uuid

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--install-directory', type=Path, required=True)
args = parser.parse_args()
installation = args.install_directory.resolve(strict=True)
assert installation.parent == ROOT / 'connected-wallet-diagnosis-20260913'
receipt = json.loads((installation / 'observation.json').read_text())
assert receipt['build'] == '2026091302'
assert receipt['status'] == 'installed-and-launched-awaiting-on-device-recovery'
os.umask(0o077)
output = installation / 'fresh-diagnostic'
output.mkdir(mode=0o700)
preferences = output / 'preferences.plist'
command = ['/usr/bin/xcrun', 'devicectl', 'device', 'copy', 'from',
           '--device', 'E91E0F25-96F2-5CB6-A7CC-EB3435002556',
           '--domain-type', 'appDataContainer', '--domain-identifier', 'co.jp.soramitsu.sora',
           '--source', 'Library/Preferences/co.jp.soramitsu.sora.plist',
           '--destination', str(preferences), '--json-output', str(output / 'copy.json')]
with (output / 'copy.log').open('w') as log:
    subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
stored = plistlib.loads(preferences.read_bytes())
raw = stored.get('walletStartupDiagnostic')
assert isinstance(raw, str) and len(raw.encode()) <= 1024, 'No bounded saved diagnostic yet'
diagnostic = json.loads(raw)
if 'walletMigrationRecoveryRecord' in stored:
    marker_raw = stored['walletMigrationRecoveryRecord']
    assert isinstance(marker_raw, str) and len(marker_raw.encode()) <= 65536
    marker = json.loads(marker_raw)
    generation = marker.get('generation')
    assert isinstance(generation, str) and str(uuid.UUID(generation)).upper() == generation
    assert marker.get('reasonGeneration') == generation
    assert marker.get('required') is True
else:
    assert stored.get('walletMigrationRecoveryRequired') is True
    generation = stored.get('walletMigrationRecoveryGeneration')
assert diagnostic.get('markerGeneration') == generation, 'Saved diagnostic belongs to an older recovery marker'
phases = set('startup_recovery journal_recovery database_migration database_inventory network_snapshot selected_account network_bootstrap'.split())
causes = set('unexpected_failure unknown_store_version unavailable_model incomplete_migration_path interrupted_migration missing_wallet_store missing_wallet_secret empty_wallet_secret insufficient_storage backup_verification_failed account_inventory_mismatch selected_account_mismatch keychain_identifier keychain_missing keychain_duplicate keychain_result keychain_system duplicate_accounts multiple_selections missing_selection legacy_upgrade_proof invalid_mnemonic invalid_derivation derivation_failed invalid_private_key snapshot_verification missing_snapshot lifecycle_busy recovery_required legacy_identity_mismatch removal_mismatch decoding_failed encoding_failed file_protection_unavailable durable_file_target durable_file_commit migration_namespace cocoa posix osstatus url'.split())
assert diagnostic['phase'] in phases and diagnostic['cause'] in causes
safe = {key: diagnostic[key] for key in ('phase', 'cause')}
code = diagnostic.get('systemCode')
assert code is None or type(code) is int
safe['systemCode'] = code
timestamp = diagnostic.get('recordedAt')
assert type(timestamp) in (int, float) and math.isfinite(timestamp)
attempted = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc) + datetime.timedelta(seconds=timestamp)
completed_installs = [entry for entry in receipt['commands'] if entry['label'] == 'install' and entry['exitCode'] == 0]
assert len(completed_installs) == 1
assert attempted >= datetime.datetime.fromisoformat(completed_installs[0]['finishedAt']), 'Diagnostic predates this install'
safe['attemptedAt'] = attempted.isoformat()
checks = diagnostic.get('secretChecks')
assert isinstance(checks, dict), 'Current failure did not record credential checks'
assert checks['origin'] in {'live_account_inventory', 'saved_manifest_validation'}
safe_checks = {'origin': checks['origin']}
for key, low, high in [('schema', 1, 2), ('accountCount', 1, 4096), ('accountNumber', 1, 4096), ('cryptoType', 0, 255), ('networkType', 0, 16383)]:
    value = checks[key]
    assert type(value) is int and low <= value <= high
    safe_checks[key] = value
assert safe_checks['accountNumber'] <= safe_checks['accountCount']
for key in ('selectedPreferenceMatches', 'watchOnly', 'snapshotPresent', 'savedSecret', 'savedEntropy', 'savedSeed'):
    if key in checks:
        assert type(checks[key]) is bool
        safe_checks[key] = checks[key]
operations = set('scoped_secret scoped_entropy scoped_seed scoped_derivation global_entropy legacy_iroha_key'.split())
outcomes = set('not_checked not_found present empty failed'.split())
observations = checks.get('outcomes', [])
if isinstance(observations, list):
    assert len(observations) <= 12 and len(observations) % 2 == 0
    assert len(set(observations[::2])) == len(observations) // 2
    observations = dict(zip(observations[::2], observations[1::2]))
assert isinstance(observations, dict) and set(observations) <= operations
assert all(value in outcomes for value in observations.values())
safe_checks['outcomes'] = observations
fallback = checks['fallback']
assert fallback in set('not_checked scoped_entropy watch_only scoped_material_present scoped_derivation_present global_entropy_not_found no_snapshot snapshot_identity_not_unique snapshot_source_not_mnemonic proving_global_identity global_identity_verified'.split())
safe_checks['fallback'] = fallback
if 'failedOperation' in checks:
    assert checks['failedOperation'] in operations
    safe_checks['failedOperation'] = checks['failedOperation']
safe['secretChecks'] = safe_checks
result = {'build': '2026091302', 'status': 'fresh-installed-diagnostic-read', 'diagnostic': safe,
          'scope': 'Fixed diagnostic codes, numeric metadata and presence outcomes only; no account identifiers or secret values.'}
(output / 'safe-observation.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
