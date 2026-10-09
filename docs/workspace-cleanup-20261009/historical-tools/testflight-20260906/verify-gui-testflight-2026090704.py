#!/usr/bin/env python3
"""Verify retained 0704 Organizer upload evidence; never upload or change source/archive inputs.

Run only after retaining Xcode's actual prepared IPA, distribution logs and the
Organizer archive whose Info.plist records the completed upload. This creates a
fresh external receipt directory. Apple processing/tester access remains a
separate App Store Connect observation.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import stat
import subprocess
import sys
import uuid
import zipfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'publish-2026090704-ios'
REVISION = 'ab0f3310fa9339c5716f09663ed53553d8ad3347'
RUNTIME = 'e886d7cfacbff119cb9bcb961cfc213882675636'
ARCHIVE = ROOT / 'next-upload-2026090704/SORA-2026090704.xcarchive'
BUILD = '2026090704'


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def regular(path):
    require(stat.S_ISREG(path.lstat().st_mode) and not path.is_symlink(), 'Expected regular evidence file: ' + str(path))
    return path.read_bytes()


def file_hashes(directory):
    result = {}
    for p in sorted(directory.rglob('*')):
        require(not p.is_symlink(), 'Symbolic archive evidence is not accepted')
        if p.is_file():
            result[str(p.relative_to(directory))] = sha(regular(p))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--organizer-archive', type=Path, required=True)
    parser.add_argument('--prepared-ipa', type=Path, required=True)
    parser.add_argument('--distribution-logs', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True, help='Fresh external receipt directory')
    args = parser.parse_args()
    organizer, ipa, logs = [p.resolve(strict=True) for p in
                            (args.organizer_archive, args.prepared_ipa, args.distribution_logs)]
    output = args.output_root.resolve()
    require(not output.exists(), 'Receipt output must be fresh')
    require(all(output != p and p not in output.parents for p in
                (SOURCE, ROOT / 'account-activation-recovery-ios', ROOT.parent / 'sora-ios', ARCHIVE, organizer, logs)),
            'Receipt output must remain outside source/archive/log inputs')
    revision = subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD']).decode().strip()
    require(revision == REVISION, 'Publication source revision changed')
    require(subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', '@{upstream}']).decode().strip() == REVISION
            and not subprocess.check_output(['git', '-C', str(SOURCE), 'status', '--porcelain=v1', '--untracked-files=all']),
            'Publication source must remain clean and pushed before loading its verifier')
    spec = importlib.util.spec_from_file_location('delivery_0704', SOURCE / 'SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py')
    verifier = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = verifier
    spec.loader.exec_module(verifier)
    require(verifier.BUILD_NUMBER == BUILD, 'Wrong delivery validator')
    original_products = file_hashes(ARCHIVE / 'Products')
    require(original_products and file_hashes(organizer / 'Products') == original_products,
            'Organizer products differ from the exact signed 0704 archive')
    archive_raw = regular(organizer / 'Info.plist')
    archive = plistlib.loads(archive_raw)
    require(archive.get('ArchiveVersion') == 2 and archive.get('Name') == 'SoraPassport' and
            archive.get('SchemeName') == 'SoraPassport', 'Organizer archive identity differs')
    app = archive.get('ApplicationProperties', {})
    require(all(app.get(k) == v for k, v in {
        'CFBundleIdentifier': verifier.BUNDLE_IDENTIFIER, 'CFBundleShortVersionString': '3.8.7',
        'CFBundleVersion': BUILD, 'SigningIdentity': verifier.SIGNING_IDENTITY, 'Team': verifier.TEAM_ID}.items()),
        'Organizer application identity differs')
    distributions = archive.get('Distributions')
    require(isinstance(distributions, list) and len(distributions) == 1,
            'Expected exactly one completed Organizer distribution')
    distribution = distributions[0]
    require(all(distribution.get(k) == v for k, v in {
        'adamId': verifier.ADAM_ID, 'certificateSHA1': verifier.SIGNING_CERTIFICATE_SHA1,
        'destination': 'upload', 'providerId': verifier.PROVIDER_ID, 'task': 'distribute',
        'teamID': verifier.TEAM_ID, 'uploadDestination': 'App Store', 'uploadedBuildNumber': BUILD}.items()),
        'Organizer distribution identity differs')
    delivery_id = distribution.get('identifier')
    require(isinstance(delivery_id, str) and str(uuid.UUID(delivery_id)) == delivery_id,
            'Missing canonical Apple delivery ID')
    _, prepared = verifier.successful_event(distribution.get('preparationEvent'),
        short_title='Prepared', title='Prepared archive for uploading')
    uploaded_at, uploaded = verifier.successful_event(distribution.get('uploadEvent'),
        short_title='Uploaded', title='Uploaded to Apple')
    require(uploaded >= prepared, 'Upload precedes preparation')
    content_log = regular(logs / 'ContentDelivery.log').decode('utf-8')
    require(delivery_id in content_log and BUILD in content_log,
            'Retained Apple delivery log does not bind the exact event/build')
    os.umask(0o077)
    output.mkdir(mode=0o700)
    shutil.copy2(ipa, output / 'SoraPassport-2026090704.ipa')
    shutil.copytree(logs, output / 'distribution-logs')
    (output / 'Organizer-Archive-Info.plist').write_bytes(archive_raw)
    unpacked = output / 'verified-extracted-package'
    unpacked.mkdir(mode=0o700)
    with zipfile.ZipFile(ipa) as package:
        for item in package.infolist():
            name = PurePosixPath(item.filename)
            require(not name.is_absolute() and '..' not in name.parts and
                    not stat.S_ISLNK(item.external_attr >> 16), 'Unsafe IPA entry')
        package.extractall(unpacked)
        for item in package.infolist():
            if not item.is_dir():
                mode = item.external_attr >> 16
                require(stat.S_ISREG(mode), 'IPA member lacks regular-file mode')
                os.chmod(unpacked / item.filename, stat.S_IMODE(mode) & 0o777)
    packaged = unpacked / 'Payload/SoraPassport.app'
    info = plistlib.loads(regular(packaged / 'Info.plist'))
    original_info = plistlib.loads(regular(ARCHIVE / 'Products/Applications/SoraPassport.app/Info.plist'))
    require(all(info.get(k) == v for k, v in {
        'CFBundleIdentifier': verifier.BUNDLE_IDENTIFIER, 'CFBundleShortVersionString': '3.8.7',
        'CFBundleVersion': BUILD, 'SoraMigrationEvidenceSourceRevision': REVISION,
        'SoraMigrationEvidenceQualificationContractSha256': original_info['SoraMigrationEvidenceQualificationContractSha256'],
        'ITSAppUsesNonExemptEncryption': False, 'TFInternalTestingOnly': True}.items()),
        'Prepared package identity/internal-only/source metadata differs')
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(packaged)], check=True)
    require(sha(regular(packaged / 'embedded.mobileprovision')) == verifier.PROVISIONING_PROFILE_SHA256,
            'Prepared package profile differs from reviewed App Store profile')
    subprocess.run(['/usr/bin/codesign', '-d', '--extract-certificates=' + str(output / 'distribution-cert'), str(packaged)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    certificate = regular(output / 'distribution-cert0')
    require(hashlib.sha1(certificate).hexdigest().upper() == verifier.SIGNING_CERTIFICATE_SHA1,
            'Prepared package distribution certificate differs')
    entitlements = plistlib.loads(subprocess.check_output(
        ['/usr/bin/codesign', '-d', '--entitlements=-', '--xml', str(packaged)], stderr=subprocess.DEVNULL))
    require(entitlements == {'application-identifier': verifier.TEAM_ID + '.' + verifier.BUNDLE_IDENTIFIER,
                            'com.apple.developer.team-identifier': verifier.TEAM_ID,
                            'get-task-allow': False, 'beta-reports-active': True},
            'Prepared package distribution entitlements differ')
    inspected = verifier.verify_app_runtime_dependency_closure(packaged)
    require(file_hashes(organizer / 'Products') == original_products and
            regular(organizer / 'Info.plist') == archive_raw, 'Organizer evidence changed during verification')
    receipt = {'status': 'uploaded-successfully', 'scope': 'exact-0704-Organizer-receipt',
        'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'deliveryId': delivery_id, 'uploadedAt': uploaded_at, 'buildNumber': BUILD, 'version': '3.8.7',
        'sourceRevision': REVISION, 'runtimeRevision': RUNTIME, 'appId': verifier.ADAM_ID, 'teamId': verifier.TEAM_ID,
        'originalArchive': str(ARCHIVE), 'organizerArchive': str(organizer),
        'identicalProductFiles': len(original_products), 'productHashes': original_products,
        'ipaSha256': sha(regular(ipa)), 'internalTestingOnly': True, 'ITSAppUsesNonExemptEncryption': False,
        'strictCodeSignature': 'passed', 'profileSha256': verifier.PROVISIONING_PROFILE_SHA256,
        'certificateSha1': verifier.SIGNING_CERTIFICATE_SHA1, 'signedEntitlements': entitlements, 'runtimeClosure': 'passed',
        'runtimeImagesInspected': len(inspected), 'archiveInfoSha256': sha(archive_raw),
        'distributionLogHashes': file_hashes(logs), 'uploadErrors': [], 'uploadWarnings': [],
        'processingAndTesterAvailability': 'Not verified by this receipt; check App Store Connect separately'}
    receipt_path = output / 'gui-upload-observation.json'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'deliveryId': delivery_id, 'uploadedAt': uploaded_at, 'receipt': str(receipt_path)}))


if __name__ == '__main__':
    main()
