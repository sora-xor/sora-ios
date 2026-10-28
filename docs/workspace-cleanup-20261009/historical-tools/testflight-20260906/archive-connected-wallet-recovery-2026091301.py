#!/usr/bin/env python3
import datetime, hashlib, json, plistlib, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'publish-2026091301-ios'
output=root/'next-upload-2026091301'
output.mkdir(mode=0o700)
archive=output/'SORA-2026091301.xcarchive'
derived=root/'next-upload-2026090704/SORA-2026090704-DerivedData'
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source).decode().strip()
assert not subprocess.check_output(['git','status','--porcelain'],cwd=source)
contract=subprocess.check_output(['/usr/bin/python3','-I','-S',str(source/'SoraPassport/Scripts/ios-migration-qualification-contract.py'),'--repository-root',str(source),'--snapshot',str(output/'qualification-source-snapshot.json')],cwd=source).decode().strip()
options=source/'SoraPassport/Configs/ios-internal-testflight-export-options.plist'
options_hash=hashlib.sha256(options.read_bytes()).hexdigest()
args=['/usr/bin/xcodebuild','-project',str(source/'SoraPassport.xcodeproj'),'-scheme','SoraPassport','-configuration','Release','-destination','generic/platform=iOS','-derivedDataPath',str(derived),'-archivePath',str(archive),'-disableAutomaticPackageResolution','-skipPackageUpdates','-allowProvisioningUpdates','CURRENT_PROJECT_VERSION=2026091301','SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE=sora-ios-internal-testflight-upload-v1','SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION=archive','SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER=2026091301','SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION='+revision,'SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256='+options_hash,'SORA_MIGRATION_EVIDENCE_SOURCE_REVISION='+revision,'SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256='+contract,'archive']
record={'sourceRevision':revision,'buildNumber':'2026091301','arguments':args,'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'intendedDistribution':'external TestFlight for both existing public-link groups','status':'building'}
receipt=output/'archive-completion-observation.json'
receipt.write_text(json.dumps(record,indent=2)+'\n')
print('Archiving corrected build2026091301',flush=True)
with (output/'archive.log').open('w') as log:
    r=subprocess.run(args,cwd=source,stdout=log,stderr=subprocess.STDOUT)
record['exitCode']=r.returncode
record['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
record['status']='archive-failed' if r.returncode else 'archived'
receipt.write_text(json.dumps(record,indent=2)+'\n')
assert r.returncode==0,'Inspect archive.log'
apps=list((archive/'Products/Applications').glob('*.app'))
assert len(apps)==1
app=apps[0]
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleVersion']=='2026091301'
assert info['CFBundleIdentifier']=='co.jp.soramitsu.sora'
assert info['SoraMigrationEvidenceSourceRevision']==revision
assert info['SoraMigrationEvidenceQualificationContractSha256']==contract
assert info['ITSAppUsesNonExemptEncryption'] is False
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(app)],check=True)
subprocess.run(['/usr/bin/python3','-I','-S',str(source/'SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py'),'--verify-app-runtime-closure',str(app)],cwd=source,check=True)
record['executableSha256']=hashlib.sha256((app/info['CFBundleExecutable']).read_bytes()).hexdigest()
record['archive']=str(archive)
record['status']='archive-verified-awaiting-external-export'
receipt.write_text(json.dumps(record,indent=2)+'\n')
print('Verified new archive; ready for authorized external TestFlight export',flush=True)
