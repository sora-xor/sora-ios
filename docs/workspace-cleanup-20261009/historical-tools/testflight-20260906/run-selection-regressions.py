#!/usr/bin/env python3
"""Run the focused callback check and relevant wallet suites in a fresh simulator."""
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import sys

root = Path('/Users/takemiyamakoto/dev/sora-wallet/testflight-20260906')
source = root / 'historical-writer-ios'
spec = importlib.util.spec_from_file_location('historical_runner', source / 'SoraPassport/Scripts/run-ios-historical-writer-upgrade.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
output = Path(sys.argv[1])
output.mkdir(mode=0o700, parents=False, exist_ok=False)
derived = root / 'historical-upgrade-run-1/DerivedData'
run = module.Run(output, derived)
run.record['scope'] = 'Release simulator callback and wallet regression tests; no upload or physical-device qualification.'
run.save()
simulator = None
try:
    run.command('create-owned-simulator', ['/usr/bin/xcrun', 'simctl', 'create', f"SORA Selection Regression {run.record['runId']}", module.DEVICE_TYPE, module.RUNTIME])
    simulator = Path(run.record['commands'][-1]['log']).read_text().strip()
    run.record['createdSimulator'] = {'udid': simulator}
    run.command('boot-owned-simulator', ['/usr/bin/xcrun', 'simctl', 'boot', simulator])
    run.command('wait-owned-simulator-boot', ['/usr/bin/xcrun', 'simctl', 'bootstatus', simulator, '-b'])
    originals = [p for p in (derived / 'Build/Products').glob('*.xctestrun') if not p.name.startswith('HistoricalWriter-')]
    assert len(originals) == 1, originals
    for label, identifiers, expected in [
        ('callback-regression', ['WalletModernizationTests/testSelectedWalletDualReadUsesCoreDataThenLegacyFallback'], 1),
        ('wallet-regressions', ['WalletModernizationTests', 'WalletRecoveryCapabilityGateTests', 'WalletRecoveryExporterTests'], 225),
    ]:
        copied, _ = module.phase_xctestrun(originals[0], label, run.record['runId'])
        value = plistlib.loads(copied.read_bytes())
        targets = [t for c in value.get('TestConfigurations', []) for t in c.get('TestTargets', [])]
        if not targets:
            targets = [v for k, v in value.items() if isinstance(v, dict) and module.target_name(k, v) == module.TARGET]
        assert len(targets) == 1
        target = targets[0]
        target['OnlyTestIdentifiers'] = identifiers
        for key in ('SORA_HISTORICAL_WRITER_PHASE', 'SORA_HISTORICAL_WRITER_RUN_ID'):
            target['EnvironmentVariables'].pop(key, None)
        copied.write_bytes(plistlib.dumps(value, sort_keys=False))
        result = output / f'{label}.xcresult'
        run.command(label, ['/usr/bin/xcodebuild', 'test-without-building', '-xctestrun', str(copied), '-destination', f'platform=iOS Simulator,id={simulator},arch=arm64', '-resultBundlePath', str(result), '-parallel-testing-enabled', 'NO'])
        run.command(f'{label}-summary', ['/usr/bin/xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(result), '--compact'])
        summary = json.loads(Path(run.record['commands'][-1]['log']).read_text())
        run.record['phases'].append({'phase': label, 'summary': summary, 'xctestrunSha256': hashlib.sha256(copied.read_bytes()).hexdigest()})
        run.save()
        assert summary.get('passedTests') == expected and summary.get('failedTests') == 0 and summary.get('skippedTests') == 0, summary
    run.record['sourceAtEnd'] = module.source_snapshot()
    assert run.record['sourceAtStart'] == run.record['sourceAtEnd'], 'Source changed during regression run'
    run.record['status'] = 'passed'
except BaseException as error:
    run.record['status'] = 'failed'
    run.record['failure'] = str(error)
    raise
finally:
    if simulator:
        run.command('shutdown-owned-simulator', ['/usr/bin/xcrun', 'simctl', 'shutdown', simulator], allow_failure=True)
    run.record['finishedAt'] = module.now()
    run.save()
