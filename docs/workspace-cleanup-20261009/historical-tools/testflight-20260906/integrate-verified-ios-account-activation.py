#!/usr/bin/env python3
"""Check, then optionally integrate the exact nine-file legacy activation correction.

Validation records the dirty tested working tree at BASE. A later clean runtime
commit must be its direct child and contain exactly those recorded file bytes.
This script never changes that historical validation revision or replaces a
primary file wholesale. Default operation writes external evidence only.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
BASE = '70d0f1dc1139d6e2c05868fa6fb7ebddf7311c17'
TARGETS = {
    'Fixtures/Modernization/ios-migration-qualification-README.md',
    'SoraPassport/Common/Extensions/SettingsExtension.swift',
    'SoraPassport/Common/Model/WalletNetworkModel.swift',
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



def committed_source_hashes(directory, revision):
    """Hash Git blob bytes independently of status, skip-worktree flags or the checkout."""
    def tree(ref):
        result = {}
        for item in git(directory, 'ls-tree', '-r', '-z', '--full-tree', ref).split(b'\0'):
            if not item:
                continue
            metadata, raw_name = item.split(b'\t', 1)
            mode, kind, oid = metadata.decode().split()
            require(kind == 'blob' and mode in {'100644', '100755'},
                    'Runtime inventory must contain tracked regular files only')
            result[raw_name.decode()] = (mode, oid)
        return result
    baseline, runtime = tree(BASE), tree(revision)
    require(set(baseline) == set(runtime) and
            all(baseline[name][0] == runtime[name][0] for name in baseline),
            'Runtime must preserve the complete tracked path and mode inventory')
    result, cached = {}, {}
    process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=directory,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        for name, (_, oid) in runtime.items():
            if oid not in cached:
                process.stdin.write((oid + '\n').encode())
                process.stdin.flush()
                header = process.stdout.readline().decode().split()
                require(len(header) == 3 and header[:2] == [oid, 'blob'], 'Git blob lookup failed')
                size = int(header[2])
                data = process.stdout.read(size)
                require(len(data) == size and process.stdout.read(1) == b'\n', 'Git blob read was truncated')
                cached[oid] = digest(data)
            result[name] = cached[oid]
        process.stdin.close()
        require(process.wait(timeout=30) == 0, 'Git blob hash process failed')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        process.stdout.close()
        process.stderr.close()
    return result


def index_hash(directory):
    path = Path(git(directory, 'rev-parse', '--git-path', 'index').decode().strip())
    if not path.is_absolute():
        path = directory / path
    return digest(path.read_bytes()) if path.exists() else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--observation', type=Path, default=ROOT / 'account-activation-recovery-validation-3/run-observation.json')
    parser.add_argument('--runtime', required=True, help='Explicit clean runtime commit created after validation; direct child of the recorded base')
    parser.add_argument('--primary', type=Path, default=ROOT.parent / 'sora-ios')
    parser.add_argument('--source', type=Path, default=ROOT / 'account-activation-recovery-ios')
    parser.add_argument('--patch', type=Path, help='Optional immutable patch; must equal the exact base-to-runtime Git diff')
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory outside both source checkouts')
    parser.add_argument('--apply', action='store_true', help='Apply after every admission check; default only checks')
    args = parser.parse_args()
    primary, source, output = (p.resolve() for p in (args.primary, args.source, args.output))
    supplied_patch = args.patch.resolve() if args.patch else None
    observation = args.observation.resolve()
    if observation.is_dir():
        observation /= 'run-observation.json'
    require(primary != source, 'Primary and tested source must be separate checkouts')
    require(all(output != p and p not in output.parents for p in (primary, source)), 'Evidence must be outside source')
    require(not output.exists(), 'Use a new evidence directory; existing evidence is retained')
    output.mkdir(parents=True, mode=0o700)
    receipt = {'status': 'checking', 'applyRequested': args.apply, 'primary': str(primary),
               'source': str(source), 'runtime': args.runtime, 'base': BASE,
               'validationRevisionMeaning': 'dirty working-tree base; tested bytes bound separately to later runtime commit',
               'observation': str(observation), 'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    receipt_path = output / 'integration-observation.json'
    applied = False
    apply_started = False
    try:
        observed_bytes = observation.read_bytes()
        observed = json.loads(observed_bytes)
        require(observed.get('status') == 'passed', 'Validation observation is not passed')
        require(observed.get('sourceRevision') == BASE, 'Historical validation must retain its actual base revision')
        require(re.fullmatch(r'[0-9a-f]{40}', args.runtime) is not None and args.runtime != BASE,
                'Runtime must be an explicit new full commit SHA')
        require(git(source, 'rev-list', '--parents', '-n', '1', args.runtime).decode().split() == [args.runtime, BASE],
                'Runtime must be exactly one direct non-merge child of the recorded validation base')
        require(git(source, 'rev-parse', 'HEAD').decode().strip() == args.runtime, 'Tested checkout revision changed')
        require(not git(source, 'status', '--porcelain=v1', '--untracked-files=all'), 'Runtime checkout must be completely clean')
        tested = source_hashes(source)
        committed = committed_source_hashes(source, args.runtime)
        require(tested == committed == observed.get('sourceAtStart') == observed.get('sourceAtEnd'),
                'Every committed runtime file must equal both actual validation snapshots and clean checkout bytes')
        for label, count in [('focused-activation', 2), ('wallet-regressions', 247)]:
            summary = observed.get(label, {})
            require(summary.get('passedTests') == count and summary.get('failedTests') == 0 and
                    summary.get('skippedTests') == 0, 'Incomplete passing test evidence: ' + label)
        for label in ['build', 'focused-activation', 'wallet-regressions', 'focused-activation-summary', 'wallet-regressions-summary']:
            commands = [item for item in observed.get('commands', []) if item.get('label') == label]
            require(len(commands) == 1 and commands[0].get('exitCode') == 0 and
                    commands[0].get('finishedAt') and Path(commands[0]['cwd']).resolve() == source,
                    'Missing successful command: ' + label)
        require(observed.get('finishedAt'), 'Validation has no terminal timestamp')
        commit_time = int(git(source, 'show', '-s', '--format=%ct', args.runtime).decode().strip())
        validated_at = datetime.datetime.fromisoformat(observed['finishedAt'].replace('Z', '+00:00'))
        require(validated_at.tzinfo is not None and commit_time >= int(validated_at.timestamp()),
                'Runtime commit must be created after terminal successful validation')
        patch_bytes = git(source, 'diff', '--binary', BASE, args.runtime)
        if supplied_patch:
            require(supplied_patch.read_bytes() == patch_bytes, 'Supplied patch is not the exact base-to-runtime diff')
        changed = set(git(source, 'diff', '--name-only', '-z', BASE, args.runtime).decode().strip('\0').split('\0'))
        require(changed == TARGETS, 'Runtime patch must modify exactly the reviewed nine files')
        require(not any(line.startswith((b'new file mode ', b'deleted file mode ', b'old mode ', b'new mode ', b'rename '))
                        for line in patch_bytes.splitlines()), 'Unexpected file or mode operation in runtime patch')
        before = inventory(primary)
        head_before = git(primary, 'rev-parse', 'HEAD').decode().strip()
        index_before = index_hash(primary)
        (output / 'primary-before.json').write_text(json.dumps(before, indent=2) + '\n')
        patch = output / 'runtime.patch'
        patch.write_bytes(patch_bytes)
        for name in sorted(TARGETS):
            require(before.get(name, {}).get('kind') == 'regular', 'Patch target is not a regular tracked file: ' + name)
            require(name in names(primary), 'Patch target is untracked: ' + name)
            if name not in PRESERVE_DIFFERENCES:
                require(before[name]['sha256'] == digest(git(source, 'show', BASE + ':' + name)),
                        'Unexpected preexisting edit in runtime target: ' + name)
            saved = output / 'before' / name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(primary / name, saved)
        git(primary, 'apply', '--check', str(patch))
        # Applying only to disposable copies computes the exact expected post-image for the two
        # files with preexisting prose/publication pins. Reverse application proves those bytes survive.
        with tempfile.TemporaryDirectory(prefix='sora-ios-account-activation-integration-') as temp:
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
                       validatedSourceRevision=BASE, integratedRuntimeRevision=args.runtime,
                       runtimeParent=BASE, sourceFileCount=len(tested),
                       validatedSourceHashSetSha256=digest(json.dumps(tested, sort_keys=True).encode()),
                       focusedTests=2, walletRegressionTests=247, runtimeCommittedAt=commit_time,
                       primaryHead=head_before, primaryIndexSha256=index_before,
                       targetBefore={name: before[name] for name in sorted(TARGETS)},
                       targetExpectedAfter=expected, exactTestedTargets=sorted(TARGETS - PRESERVE_DIFFERENCES),
                       patchOnlyTargets=sorted(PRESERVE_DIFFERENCES), unrelatedFiles=len(before) - len(TARGETS))
        # Recheck every admission immediately before a possible primary mutation.
        require(inventory(primary) == before and index_hash(primary) == index_before and
                git(primary, 'rev-parse', 'HEAD').decode().strip() == head_before, 'Primary changed during preparation')
        require(patch.read_bytes() == patch_bytes and observation.read_bytes() == observed_bytes and
                source_hashes(source) == tested and git(source, 'rev-parse', 'HEAD').decode().strip() == args.runtime and
                not git(source, 'status', '--porcelain=v1', '--untracked-files=all'),
                'Tested input changed during preparation')
        if args.apply:
            apply_started = True
            receipt.update(status='applying', applyStartedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
            receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
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
        receipt.update(status='applied-verification-failed' if applied else
                       ('apply-attempt-failed-evidence-preserved' if apply_started else 'rejected-without-apply'),
                       failure=str(error))
        raise
    finally:
        receipt['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
