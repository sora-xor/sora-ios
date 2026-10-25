#!/usr/bin/env python3
"""Check, then optionally apply the tested interruption patch without replacing primary files wholesale."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
BASE = '2a1ee11b77938886a95751946469c15ce10b8dd8'
TARGETS = {
    'Fixtures/Modernization/ios-migration-qualification-README.md',
    'SoraPassport/Common/Extensions/SettingsExtension.swift',
    'SoraPassport/Common/Migration/InconsistentStateMigrator.swift',
    'SoraPassport/Common/Migration/StorageMigrator.swift',
    'SoraPassport/Common/Model/WalletNetworkModel.swift',
    'SoraPassport/Common/Storage/SelectedWalletSettings.swift',
    'SoraPassport/ModulesRedesign/AccountOptions/AccountOptionsInteractor.swift',
    'SoraPassport/ModulesRedesign/Root/RootInteractor.swift',
    'SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift',
    'SoraPassport/Scripts/collect-ios-migration-evidence.py',
    'SoraPassport/Scripts/test-ios-migration-evidence-collector.py',
    'SoraPassport/Scripts/verify-modernization-dependencies.sh',
    'SoraPassportTests/Common/Modernization/WalletModernizationTests.swift',
}
PRESERVE_DIFFERENCES = {
    'Fixtures/Modernization/ios-migration-qualification-README.md',
    'SoraPassport/Scripts/verify-modernization-dependencies.sh',
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(directory, *args):
    return subprocess.check_output(['git', *args], cwd=directory, stderr=subprocess.STDOUT)


def names(directory, untracked=False):
    args = ['ls-files', '-z']
    if untracked:
        args += ['--cached', '--others', '--exclude-standard']
    return sorted(set(p for p in git(directory, *args).decode().split('\0') if p))


def entry(path):
    if not path.exists() and not path.is_symlink():
        return {'kind': 'missing'}
    metadata = path.lstat()
    result = {'mode': stat.S_IMODE(metadata.st_mode)}
    if stat.S_ISREG(metadata.st_mode):
        result.update(kind='regular', sha256=digest(path.read_bytes()))
    elif stat.S_ISLNK(metadata.st_mode):
        result.update(kind='symlink', target=os.readlink(path))
    else:
        result.update(kind='directory' if stat.S_ISDIR(metadata.st_mode) else 'other')
    return result


def inventory(directory):
    return {name: entry(directory / name) for name in names(directory, untracked=True)}


def source_hashes(directory):
    result = {}
    for name in names(directory):
        record = entry(directory / name)
        if record['kind'] == 'regular':
            result[name] = record['sha256']
        else:
            require(record['kind'] == 'directory', 'Unexpected non-regular tested source: ' + name)
    return result


def index_hash(directory):
    path = Path(git(directory, 'rev-parse', '--git-path', 'index').decode().strip())
    if not path.is_absolute():
        path = directory / path
    return digest(path.read_bytes()) if path.exists() else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--observation', type=Path, default=ROOT / 'interruption-recovery-validation-2/run-observation.json')
    parser.add_argument('--runtime', required=True, help='Exact tested runtime commit; never inferred from a branch name')
    parser.add_argument('--base', default=BASE)
    parser.add_argument('--primary', type=Path, default=ROOT.parent / 'sora-ios')
    parser.add_argument('--source', type=Path, default=ROOT / 'interruption-recovery-ios')
    parser.add_argument('--patch', type=Path, default=ROOT / 'interruption-recovery-runtime.patch')
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory outside both source checkouts')
    parser.add_argument('--apply', action='store_true', help='Apply after every admission check; default only checks')
    args = parser.parse_args()
    primary, source, patch, output = (p.resolve() for p in (args.primary, args.source, args.patch, args.output))
    observation = args.observation.resolve()
    if observation.is_dir():
        observation /= 'run-observation.json'
    require(primary != source, 'Primary and tested source must be separate checkouts')
    require(all(output != p and p not in output.parents for p in (primary, source)), 'Evidence must be outside source')
    require(not output.exists(), 'Use a new evidence directory; existing evidence is retained')
    output.mkdir(parents=True, mode=0o700)
    receipt = {'status': 'checking', 'applyRequested': args.apply, 'primary': str(primary),
               'source': str(source), 'runtime': args.runtime, 'base': args.base,
               'observation': str(observation), 'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    receipt_path = output / 'integration-observation.json'
    applied = False
    try:
        observed_bytes = observation.read_bytes()
        observed = json.loads(observed_bytes)
        require(observed.get('status') == 'passed', 'Validation observation is not passed')
        require(observed.get('sourceRevision') == args.runtime, 'Validation revision mismatch')
        require(git(source, 'rev-parse', 'HEAD').decode().strip() == args.runtime, 'Tested checkout revision changed')
        require(not git(source, 'diff', '--name-only', 'HEAD').strip(), 'Tested tracked source is dirty')
        tested = source_hashes(source)
        require(tested == observed.get('sourceAtStart') == observed.get('sourceAtEnd'), 'Validation/source hash mismatch')
        for label, count in [('focused-interruption', 5), ('wallet-regressions', 245)]:
            summary = observed.get(label, {})
            require(summary.get('passedTests') == count and summary.get('failedTests') == 0 and
                    summary.get('skippedTests') == 0, 'Incomplete passing test evidence: ' + label)
        for label in ['build', 'focused-interruption', 'wallet-regressions']:
            commands = [item for item in observed.get('commands', []) if item.get('label') == label]
            require(len(commands) == 1 and commands[0].get('exitCode') == 0 and
                    commands[0].get('finishedAt') and Path(commands[0]['cwd']).resolve() == source,
                    'Missing successful command: ' + label)
        require(observed.get('finishedAt'), 'Validation has no terminal timestamp')
        patch_bytes = patch.read_bytes()
        require(patch_bytes == git(source, 'diff', '--binary', args.base, args.runtime), 'Patch is not the exact base-to-runtime diff')
        changed = set(git(source, 'diff', '--name-only', '-z', args.base, args.runtime).decode().strip('\0').split('\0'))
        require(changed == TARGETS, 'Runtime patch must modify exactly the reviewed 13 files')
        require(not any(line.startswith((b'new file mode ', b'deleted file mode ', b'old mode ', b'new mode ', b'rename '))
                        for line in patch_bytes.splitlines()), 'Unexpected file or mode operation in runtime patch')
        before = inventory(primary)
        head_before = git(primary, 'rev-parse', 'HEAD').decode().strip()
        index_before = index_hash(primary)
        (output / 'primary-before.json').write_text(json.dumps(before, indent=2) + '\n')
        (output / 'runtime.patch').write_bytes(patch_bytes)
        for name in sorted(TARGETS):
            require(before.get(name, {}).get('kind') == 'regular', 'Patch target is not a regular tracked file: ' + name)
            require(name in names(primary), 'Patch target is untracked: ' + name)
            if name not in PRESERVE_DIFFERENCES:
                require(before[name]['sha256'] == digest(git(source, 'show', args.base + ':' + name)),
                        'Unexpected preexisting edit in runtime target: ' + name)
            saved = output / 'before' / name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(primary / name, saved)
        git(primary, 'apply', '--check', str(patch))
        # Applying only to disposable copies computes the exact expected post-image for the two
        # files with preexisting prose/publication pins. Reverse application proves those bytes survive.
        with tempfile.TemporaryDirectory(prefix='sora-ios-interruption-integration-') as temp:
            scratch = Path(temp)
            for name in TARGETS:
                target = scratch / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(primary / name, target)
            git(scratch, 'apply', '--check', str(patch))
            git(scratch, 'apply', str(patch))
            expected = {name: entry(scratch / name) for name in TARGETS}
            for name in TARGETS - PRESERVE_DIFFERENCES:
                require(expected[name]['sha256'] == tested[name], 'Expected patched file differs from tested source: ' + name)
            git(scratch, 'apply', '--reverse', str(patch))
            require(all(entry(scratch / name) == before[name] for name in TARGETS), 'Patch round-trip changed baseline bytes or modes')
        receipt.update(observationSha256=digest(observed_bytes), patchSha256=digest(patch_bytes),
                       primaryHead=head_before, primaryIndexSha256=index_before,
                       targetBefore={name: before[name] for name in sorted(TARGETS)},
                       targetExpectedAfter=expected, exactTestedTargets=sorted(TARGETS - PRESERVE_DIFFERENCES),
                       patchOnlyTargets=sorted(PRESERVE_DIFFERENCES), unrelatedFiles=len(before) - len(TARGETS))
        # Recheck every admission immediately before a possible primary mutation.
        require(inventory(primary) == before and index_hash(primary) == index_before and
                git(primary, 'rev-parse', 'HEAD').decode().strip() == head_before, 'Primary changed during preparation')
        require(patch.read_bytes() == patch_bytes and observation.read_bytes() == observed_bytes and
                source_hashes(source) == tested and git(source, 'rev-parse', 'HEAD').decode().strip() == args.runtime,
                'Tested input changed during preparation')
        if args.apply:
            git(primary, 'apply', str(patch))
            applied = True
            after = inventory(primary)
            (output / 'primary-after.json').write_text(json.dumps(after, indent=2) + '\n')
            require(set(after) == set(before), 'Primary file inventory changed beyond the patch')
            require(all(after[name] == expected[name] if name in TARGETS else after[name] == before[name]
                        for name in before), 'Post-apply content/mode preservation check failed')
            require(index_hash(primary) == index_before and git(primary, 'rev-parse', 'HEAD').decode().strip() == head_before,
                    'Primary index or HEAD changed')
            receipt['status'] = 'applied-and-verified'
        else:
            receipt['status'] = 'checked-not-applied'
        print(json.dumps({'status': receipt['status'], 'receipt': str(receipt_path), 'files': len(TARGETS)}))
    except BaseException as error:
        receipt.update(status='applied-verification-failed' if applied else 'rejected-without-apply', failure=str(error))
        raise
    finally:
        receipt['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
