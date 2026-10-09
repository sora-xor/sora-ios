#!/usr/bin/env python3
"""Build and test the isolated resume-authentication fixture on an owned simulator."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent
source = root / 'resume-auth-fixture-ios'
output = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'resume-auth-fixture-validation-1'
output = output.resolve()
output.mkdir(mode=0o700)
derived = output / 'DerivedData'
record_path = output / 'run-observation.json'
record = {'scope': 'Release simulator26 WalletUX tests, test-only resume authorization attachment fixture correction', 'commands': [], 'status': 'running'}
simulator = None

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def save():
    record_path.write_text(json.dumps(record, indent=2) + '\n')

def snapshot():
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=source).decode().split('\0')
    return {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
            for name in paths if name and (source / name).is_file()}

def command(label, args, allow_failure=False):
    log = output / (label + '.log')
    entry = {'label': label, 'arguments': args, 'cwd': str(source), 'startedAt': now(), 'log': str(log)}
    record['commands'].append(entry)
    save()
    print(label, 'started', flush=True)
    with log.open('w') as stream:
        result = subprocess.run(args, cwd=source, stdout=stream, stderr=subprocess.STDOUT)
    entry.update(exitCode=result.returncode, finishedAt=now())
    save()
    print(label, 'exit', result.returncode, flush=True)
    if result.returncode and not allow_failure:
        raise RuntimeError(label + ' failed; inspect ' + str(log))
    return log.read_text()

record['startedAt'] = now()
record['xcodeVersion'] = subprocess.check_output(['/usr/bin/xcodebuild', '-version']).decode().strip()
record['runtime'] = 'com.apple.CoreSimulator.SimRuntime.iOS-18-4'
record['sourceAtStart'] = snapshot()
record['sourceRevision'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source).decode().strip()
save()
try:
    simulator = command('create-simulator', ['/usr/bin/xcrun', 'simctl', 'create',
        'SORA Resume Auth Fixture 20260922', 'com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro',
        'com.apple.CoreSimulator.SimRuntime.iOS-18-4']).strip()
    record['ownedSimulator'] = simulator
    save()
    command('boot-simulator', ['/usr/bin/xcrun', 'simctl', 'boot', simulator])
    command('boot-status', ['/usr/bin/xcrun', 'simctl', 'bootstatus', simulator, '-b'])
    destination = 'platform=iOS Simulator,id=' + simulator + ',arch=arm64'
    suites = ['WalletUXTests']
    command('build', ['/usr/bin/xcodebuild', 'build-for-testing', '-project', str(source / 'SoraPassport.xcodeproj'),
        '-scheme', 'SoraPassport', '-configuration', 'Release', '-destination', destination,
        '-derivedDataPath', str(derived), '-resultBundlePath', str(output / 'build.xcresult'),
        '-parallel-testing-enabled', 'NO', '-disableAutomaticPackageResolution', '-skipPackageUpdates',
        '-clonedSourcePackagesDirPath', str(output / 'SourcePackages'),
        'SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE=sora-ios-nonpromoting-release-simulator-test-v1',
        'SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION=test', 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO',
        'ENABLE_TESTABILITY=YES', 'ONLY_ACTIVE_ARCH=YES', 'ARCHS=arm64', 'EXCLUDED_ARCHS=x86_64'] +
        ['-only-testing:SoraPassportTests/' + suite for suite in suites])
    assert snapshot() == record['sourceAtStart'], 'Source changed during build'
    plans = [p for p in (derived / 'Build/Products').glob('*.xctestrun') if not p.name.startswith('HistoricalWriter-')]
    assert len(plans) == 1, plans
    record['testPlan'] = str(plans[0])
    expected_counts = {}
    import re
    for suite in suites:
        matches = ([source / 'SoraPassportTests/Modules/OnboardingMain/OnboardingMainInteractorTests.swift']
                   if suite == 'GoogleImportResponseTests' else list(source.glob('SoraPassportTests/**/' + suite + '.swift')))
        assert len(matches) == 1, matches
        if suite == 'GoogleImportResponseTests':
            expected_counts[suite] = 3
            continue
        expected_counts[suite] = len(re.findall(r'^    func test[^\n(]*\(', matches[0].read_text(), re.M))
    assert expected_counts == {'WalletUXTests': 26}, expected_counts
    record['expectedSuiteCounts'] = expected_counts
    save()
    for label, tests, expected in [
        ('wallet-regressions', suites, sum(expected_counts.values())),
    ]:
        result_path = output / (label + '.xcresult')
        command(label, ['/usr/bin/xcodebuild', 'test-without-building', '-xctestrun', str(plans[0]),
            '-destination', destination, '-resultBundlePath', str(result_path), '-parallel-testing-enabled', 'NO'] +
            ['-only-testing:SoraPassportTests/' + test for test in tests], allow_failure=True)
        test_exit = record['commands'][-1]['exitCode']
        summary = json.loads(command(label + '-summary', ['/usr/bin/xcrun', 'xcresulttool', 'get', 'test-results',
            'summary', '--path', str(result_path), '--compact']))
        record[label] = summary
        save()
        assert test_exit == 0, f'{label} failed with exit {test_exit}'
        assert summary.get('passedTests') == expected and summary.get('failedTests') == 0 and summary.get('skippedTests') == 0, summary
    record['sourceAtEnd'] = snapshot()
    assert record['sourceAtEnd'] == record['sourceAtStart'], 'Source changed during testing'
    record['status'] = 'passed'
except BaseException as error:
    record.update(status='failed', failure=str(error))
    raise
finally:
    record['sourceAtEnd'] = snapshot()
    record['sourceHashesUnchanged'] = record['sourceAtEnd'] == record['sourceAtStart']
    if not record['sourceHashesUnchanged']:
        record.update(status='failed', failure='Source changed during validation')
    if simulator:
        command('shutdown-owned-simulator', ['/usr/bin/xcrun', 'simctl', 'shutdown', simulator], allow_failure=True)
        command('delete-owned-simulator', ['/usr/bin/xcrun', 'simctl', 'delete', simulator], allow_failure=True)
    record['finishedAt'] = now()
    save()
