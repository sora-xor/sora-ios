#!/usr/bin/env python3
"""Verify the independently prepared exact candidate after full validation; leave source checkout frozen."""
import datetime, hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'wallet-cloud-recovery-ios'
candidate=root/'publish-2026091303-ios'
validation_path=root/'wallet-cloud-recovery-validation-1/run-observation.json'
validation=json.loads(validation_path.read_text())
assert validation['status']=='passed'
assert {k:validation['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')}=={'passedTests':274,'failedTests':0,'skippedTests':0}
base='443b750041f8595996876c663b229e7ac3db6804'
def git(path,*args): return subprocess.check_output(['git','-C',str(path),*args])
assert git(source,'rev-parse','HEAD').decode().strip()==base==validation['sourceRevision']
assert git(source,'branch','--show-current').decode().strip()=='codex/ios-wallet-cloud-recovery-20260913'
assert not git(source,'diff','--cached','--name-only')
assert not git(source,'ls-files','--others','--exclude-standard')
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
publication=git(candidate,'rev-parse','HEAD').decode().strip()
runtime=git(candidate,'rev-parse','HEAD^').decode().strip()
assert git(candidate,'rev-list','--parents','-n','1',runtime).decode().split()==[runtime,base]
assert git(candidate,'rev-parse','@{upstream}').decode().strip()==publication
files=git(source,'diff','--name-only').decode().splitlines();assert set(files) <= {'SoraPassport/ModulesRedesign/Root/RootWireframe.swift','SoraPassport/Common/Migration/StorageMigrator.swift','SoraPassport/Common/Storage/SelectedWalletSettings.swift','SoraPassportTests/Common/Modernization/WalletUXTests.swift','SoraPassportTests/Common/Modernization/WalletModernizationTests.swift','SoraPassport/Scripts/verify-modernization-dependencies.sh', 'SoraPassport/Scripts/collect-ios-migration-evidence.py', 'SoraPassport/Scripts/test-ios-migration-evidence-collector.py'} and len(files) == 8
inventory={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in git(source,'ls-files','-z').decode().split('\0') if n and (source/n).is_file()}
assert inventory==validation['sourceAtStart']==validation['sourceAtEnd']
patch=git(source,'diff','--binary','--full-index',base)
assert patch==git(candidate,'diff','--binary','--full-index',base,runtime)
assert len(git(candidate,'diff','--name-only',runtime,publication).decode().splitlines())==4
output=root/'wallet-cloud-recovery-evidence/runtime-commit-observation.json';assert not output.exists()
assert git(source,'rev-parse','HEAD').decode().strip()==base
assert not git(source,'diff','--cached','--name-only')
assert inventory=={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in inventory}
output.write_text(json.dumps({'runtimeRevision':runtime,'publicationRevision':publication,'parent':base,'validationReceipt':str(validation_path),'validationReceiptSha256':hashlib.sha256(validation_path.read_bytes()).hexdigest(),'files':files,'trackedFiles':len(inventory),'passedWalletTests':274,'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Candidate prepared concurrently; independently verified after full validation and exact binary patch verification. Original source HEAD, index and working files remain unchanged.'},indent=2)+'\n')
print('Verified committed candidate runtime '+runtime+'; validation checkout unchanged',flush=True)
