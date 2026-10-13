#!/usr/bin/env python3
"""Prepare existing1402 package, local-export, Organizer and upload-receipt helpers; execute no release operation.

Run only after publish-2026091402-ios-r2 is committed, clean, and pushed. This
prepares evidence-side scripts only; it never imports, exports, or uploads an
archive and does not modify the publication checkout or prior receipts.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'publish-2026091402-ios-r2'
PREVIOUS = ROOT / 'external-publication-2026091401-r2'
OUTPUT = ROOT / 'external-publication-2026091402-r2'
BUILD = '2026091402'
# This exact Organizer directory was observed on September 13. The existing
# helper requires an already present parent; do not invent a new calendar folder.
OBSERVED_ORGANIZER_PARENT = Path.home() / 'Library/Developer/Xcode/Archives/0008-09-08'
TEMPLATES = {'verify-external-package.py': (8, 4), 'retain-external-upload.py': (6, 2), 'import-verified-archive-to-organizer.py': (5, 2), 'export-local-external-ipa-automatic.py': (3, 2), 'retain-symbol-warning-upload.py': (6, 4)}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*arguments):
    return subprocess.check_output(['/usr/bin/git', '-C', str(SOURCE), *arguments],
                                   text=True).strip()


def replace_one(text, old, new):
    require(text.count(old) == 1, 'Prior helper shape differs: ' + old)
    return text.replace(old, new)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--organizer-parent', type=Path, default=OBSERVED_ORGANIZER_PARENT,
                        help='Already observed existing Organizer folder; default preserves the September 13 observation')
    args = parser.parse_args()
    require(not OUTPUT.exists() and not OUTPUT.is_symlink(), 'Fresh external-publication-2026091402-r2 output required')
    require(SOURCE.is_dir(), 'Publication worktree does not exist yet')
    publication = git('rev-parse', 'HEAD')
    runtime = git('rev-parse', 'HEAD^')
    require(re.fullmatch('[0-9a-f]{40}', publication) and re.fullmatch('[0-9a-f]{40}', runtime),
            'Expected committed publication and direct runtime parent')
    require(git('rev-parse', '@{upstream}') == publication and
            not git('status', '--porcelain=v1', '--untracked-files=all'),
            'Publication must be clean and equal to its upstream')
    candidate_path = ROOT / 'publication-candidate-preparation-2026091402-r2/candidate-observation.json'
    candidate = json.loads(candidate_path.read_bytes())
    require(publication == candidate.get('publicationRevision') == '5a362b31a27003695d0d90c787e603bc5b33ad24' and
            runtime == candidate.get('runtimeRevision') == 'bd2641aa55c8081b457316ed19f4cccbc0257313',
            'Observed final1402 candidate R/P association differs')
    destination = args.organizer_parent.expanduser().absolute() / ('SORA-' + BUILD + '.xcarchive')
    prepared = {}
    source_hashes = {}
    for name, (long_count, short_count) in TEMPLATES.items():
        original = (PREVIOUS / name).read_bytes()
        text = original.decode('utf-8')
        require(text.count('2026091401') == long_count and
                text.replace('2026091401', '').count('1401') == short_count,
                'Prior release token inventory differs: ' + name)
        text = text.replace('publish-2026091401-ios-r2', 'publish-2026091402-ios-r2')
        text = text.replace('2026091401', BUILD).replace('1401', '1402')
        if name == 'verify-external-package.py':
            text = replace_one(text, "REVISION = 'f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'", 'REVISION = ' + repr(publication))
            text = replace_one(text, "RUNTIME = '3631769220a9c0b6aeb06592af79aacf329c095a'", 'RUNTIME = ' + repr(runtime))
        elif name == 'retain-symbol-warning-upload.py':
            text = replace_one(text, 'f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5', publication)
            text = replace_one(text, '3631769220a9c0b6aeb06592af79aacf329c095a', runtime)
        elif name == 'import-verified-archive-to-organizer.py':
            text = re.sub(r'^DESTINATION = .+$', 'DESTINATION = Path(' + repr(str(destination)) + ')', text, count=1, flags=re.MULTILINE)
        # Parse only; none of the generated module bodies or operations execute.
        compile(text, str(OUTPUT / name), 'exec')
        prepared[name] = text.encode('utf-8')
        source_hashes[name] = sha(original)
    require(git('rev-parse', 'HEAD') == publication and git('rev-parse', '@{upstream}') == publication and
            git('rev-parse', 'HEAD^') == runtime and
            not git('status', '--porcelain=v1', '--untracked-files=all'),
            'Publication changed during preparation')
    # Atomic mkdir refuses an existing output and leaves earlier evidence alone.
    os.umask(0o077)
    OUTPUT.mkdir(mode=0o700)
    for name, data in prepared.items():
        path = OUTPUT / name
        with path.open('xb') as handle:
            handle.write(data)
        path.chmod(0o700)
    receipt = {
        'status': 'helpers-prepared-not-executed',
        'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'buildNumber': BUILD, 'sourceRevision': publication, 'runtimeRevision': runtime,
        'source': str(SOURCE), 'upstreamMatched': True, 'sourceClean': True,
        'candidateReceiptSHA256': sha(candidate_path.read_bytes()),
        'canonicalValidationStatus': 'pending; helpers do not authorize upload',
        'previousHelpers': str(PREVIOUS), 'previousHelperSha256': source_hashes,
        'preparedHelperSha256': {name: sha(data) for name, data in prepared.items()},
        'nativeArchivePathFamily': str(ROOT / ('next-upload-' + BUILD)) + '*',
        'organizerArchive': str(destination),
        'scope': 'Release pins and paths only; all existing package/signing/distribution verification retained. '
                 'No archive import, export, upload, source change, account change, or tester mutation executed.',
    }
    (OUTPUT / 'helper-preparation-observation.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'status': receipt['status'], 'sourceRevision': publication, 'runtimeRevision': runtime,
                      'output': str(OUTPUT), 'organizerArchive': str(destination)}, indent=2))


if __name__ == '__main__':
    main()
