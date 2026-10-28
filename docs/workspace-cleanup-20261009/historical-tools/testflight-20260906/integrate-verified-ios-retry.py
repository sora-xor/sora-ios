#!/usr/bin/env python3
"""Apply only the seven verified retry/callback files after validation3 passed.
Requires --apply. Does not stage, commit, push, merge or publish anything.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile

BASE = Path(__file__).resolve().parent
PRIMARY = BASE.parent / 'sora-ios'
SOURCE = BASE / 'upgrade-retry-ios'
VALIDATION = BASE / 'upgrade-retry-validation-3/run-observation.json'
PRIMARY_HEAD = '9a69699414f14e73bb0c832d155b9835f9190699'
FILES = {
    'SoraPassport/ModulesRedesign/SplashScreen/SplashFactory.swift': ('7d02670f27d81710c139db26be0cecf15a867cdf8bd13c3350f84516c6b990b2', '3ab1097e063aafcccecfda9d954dc3f8149a962a00fa2fba4897646dd98e7aae'),
    'SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift': ('c89389420dede59961d69198caaeb8512972f4c6fb9796ac890c91e7b6b18c5c', '09b9400116a15f9c81c99882505e0c10b6a42bdfdcb24647ba58348376339b97'),
    'SoraPassport/ModulesRedesign/SplashScreen/SplashPresenter.swift': ('6bc787e9149851bda6d989b8f31807d233c402941462b54fbaac1958b70a4bbe', '77fdf70518952b42300247f5eadc8d5e903a56222ae096e80f1eac7c924967e3'),
    'SoraPassport/ModulesRedesign/SplashScreen/SplashViewController.swift': ('fc90fcb5610042ad42c7f104359055de885696194807ce2469b43f331086f16e', 'c70fc06f6f4304990018c32e2652f62672a2f417462d407655cf5a9bdc51cab4'),
    'SoraPassportTests/Common/Modernization/WalletModernizationTests.swift': ('77685258b6f20d9dc2d3bcb2b0e75a8d72ca1900e5163ef8a236feafc40a80ac', '3b5a7c94e91b5d2e3027e80559fc70b115ded09a4203f150cdc07cf49903ed1b'),
    'SoraPassportTests/Common/Modernization/WalletUXTests.swift': ('8578245eae35e2ffd8406655fc7512014afb2aca229e9c32af4ec3d004505ab8', '1a6c34b976d8cf3333f5319ee7eeb074e9697b49bce0f01b74d31f2b80268138'),
    'SoraPassport/Common/Storage/SelectedWalletSettings.swift': ('37afa14759974ed3b0e757cf19889aaaa3020b4fe48571962dfd6068c23d0017', '58956331a47d3c55d1290f36dfed606c9a964bbddfd4b09eeec7bb0750c2d60c'),
}

def require(value, message):
    if not value:
        raise ValueError(message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git(root, *args):
    return subprocess.check_output(['/usr/bin/git', '-C', str(root), *args])

def regular(path):
    require(path.is_file() and not path.is_symlink(), 'Expected regular file: ' + str(path))
    return path.read_bytes()

def source_snapshot():
    names = git(SOURCE, 'ls-files', '-z').decode().split('\0')
    return {name: sha(regular(SOURCE / name)) for name in names if name and (SOURCE / name).is_file()}

def primary_snapshot():
    result = {}
    for name in git(PRIMARY, 'ls-files', '-z').decode().split('\0'):
        if not name:
            continue
        path = PRIMARY / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            data = os.readlink(path).encode()
        else:
            require(stat.S_ISREG(info.st_mode), 'Unexpected non-file tracked source: ' + name)
            data = path.read_bytes()
        result[name] = (sha(data), stat.S_IMODE(info.st_mode))
    return result

def clean_primary():
    require(git(PRIMARY, 'rev-parse', 'HEAD').decode().strip() == PRIMARY_HEAD, 'Primary HEAD changed')
    require(git(PRIMARY, 'branch', '--show-current').decode().strip() == 'modernize', 'Primary branch changed')
    require(not git(PRIMARY, 'status', '--porcelain=v1', '--untracked-files=all'), 'Primary is not clean')

def check_counts(summary, expected, label):
    require(summary.get('passedTests') == expected and summary.get('failedTests') == 0
            and summary.get('skippedTests') == 0, 'Validation counts are not exact: ' + label)

def replace_file(path, data, mode, expected):
    require(sha(regular(path)) == expected, 'Primary file changed before copy: ' + str(path))
    fd, temporary = tempfile.mkstemp(prefix='.verified-retry-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            os.fchmod(stream.fileno(), mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        require(sha(regular(path)) == expected, 'Concurrent primary edit detected: ' + str(path))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', required=True)
    parser.add_argument('--observation', type=Path,
                        default=BASE / 'upgrade-retry-primary-integration-observation.json')
    args = parser.parse_args()
    output = args.observation
    require(output.is_absolute() and output.parent.resolve(strict=True) == output.parent,
            'Observation must have a canonical existing absolute parent')
    require(not output.is_relative_to(PRIMARY) and not output.is_relative_to(SOURCE),
            'Observation must remain outside source')
    require(not output.exists() and not output.is_symlink(), 'Observation already exists')
    raw = regular(VALIDATION)
    evidence = json.loads(raw)
    require(evidence.get('status') == 'passed' and evidence.get('finishedAt'), 'Validation3 is not terminal passed')
    validated = evidence.get('sourceAtStart')
    require(isinstance(validated, dict) and validated and evidence.get('sourceAtEnd') == validated,
            'Validation3 did not retain identical start/end source hashes')
    summaries = {}
    for label, count in [('focused-retry', 3), ('wallet-regressions', 240)]:
        check_counts(evidence.get(label, {}), count, label)
        result_path = VALIDATION.parent / (label + '.xcresult')
        require(result_path.is_dir() and not result_path.is_symlink(), 'Missing actual XCResult: ' + label)
        actual = json.loads(subprocess.check_output(['/usr/bin/xcrun', 'xcresulttool', 'get',
            'test-results', 'summary', '--path', str(result_path), '--compact']))
        check_counts(actual, count, label + ' actual XCResult')
        summaries[label] = {'passed': count, 'failed': 0, 'skipped': 0,
                            'xcresult': str(result_path),
                            'summarySha256': sha(json.dumps(actual, sort_keys=True).encode())}
    for label in ['build', 'focused-retry', 'focused-retry-summary', 'wallet-regressions', 'wallet-regressions-summary']:
        commands = [entry for entry in evidence.get('commands', []) if entry.get('label') == label]
        require(len(commands) == 1 and commands[0].get('exitCode') == 0,
                'Validation command was not exactly once successful: ' + label)
    require(source_snapshot() == validated, 'Current source differs from validated source')
    clean_primary()
    before = primary_snapshot()
    contents = {}
    for name, (old_hash, new_hash) in FILES.items():
        contents[name] = regular(SOURCE / name)
        require(validated.get(name) == new_hash and sha(contents[name]) == new_hash,
                'Validated target hash drifted: ' + name)
        require(before.get(name, (None,))[0] == old_hash, 'Primary before hash drifted: ' + name)
    record = {'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'primary': str(PRIMARY), 'primaryHead': PRIMARY_HEAD, 'source': str(SOURCE),
              'sourceRevision': git(SOURCE, 'rev-parse', 'HEAD').decode().strip(),
              'validationObservation': str(VALIDATION), 'validationSha256': sha(raw),
              'validatedTrackedSourceCount': len(validated), 'validation': summaries,
              'files': {name: {'beforeSha256': old, 'afterSha256': new, 'mode': oct(before[name][1])}
                        for name, (old, new) in sorted(FILES.items())},
              'appliedPaths': [], 'status': 'applying',
              'staged': False, 'committed': False, 'pushed': False,
              'wholePrimaryBranchTested': False, 'productionQualification': False}
    os.umask(0o077)
    output.open('x').close()
    def save():
        output.write_text(json.dumps(record, indent=2) + '\n')
    save()
    try:
        clean_primary()
        require(primary_snapshot() == before, 'Primary changed before integration')
        require(source_snapshot() == validated and regular(VALIDATION) == raw,
                'Validation/source changed before integration')
        for name in sorted(FILES):
            replace_file(PRIMARY / name, contents[name], before[name][1], FILES[name][0])
            record['appliedPaths'].append(name)
            save()
        expected = dict(before)
        for name, (_, new_hash) in FILES.items():
            expected[name] = (new_hash, before[name][1])
        require(primary_snapshot() == expected, 'Source outside the seven exact files changed')
        require(git(PRIMARY, 'rev-parse', 'HEAD').decode().strip() == PRIMARY_HEAD, 'HEAD changed during integration')
        require(not git(PRIMARY, 'diff', '--cached', '--name-only'), 'Integration must not stage anything')
        expected_status = ''.join(' M ' + name + '\n' for name in sorted(FILES)).encode()
        require(git(PRIMARY, 'status', '--porcelain=v1', '--untracked-files=all') == expected_status,
                'Unexpected additional/staged/untracked primary edits')
        expected_diff = ''.join('M\t' + name + '\n' for name in sorted(FILES)).encode()
        require(git(PRIMARY, 'diff', '--name-status', '--no-renames', 'HEAD') == expected_diff,
                'Integration diff must be exactly seven modified paths')
        subprocess.run(['/usr/bin/git', '-C', str(PRIMARY), 'diff', '--check'], check=True)
        require(source_snapshot() == validated, 'Validated source changed during integration')
        record['unrelatedTrackedFilesUnchanged'] = len(before) - len(FILES)
        record['preservedFileModes'] = True
        record['status'] = 'integrated-seven-verified-files'
    except BaseException as error:
        record['status'] = 'failed-evidence-preserved'
        record['errorClass'] = type(error).__name__
        # Preserve evidence/partial progress instead of automatically overwriting concurrent work.
        raise
    finally:
        record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()
    print(str(output))
    print(record['status'])

if __name__ == '__main__':
    main()
