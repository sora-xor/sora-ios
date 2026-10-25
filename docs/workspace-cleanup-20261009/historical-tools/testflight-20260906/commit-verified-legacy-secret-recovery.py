#!/usr/bin/env python3
import datetime, hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'legacy-secret-recovery-ios'
validation_path=root/'legacy-secret-recovery-validation-4/run-observation.json'
validation=json.loads(validation_path.read_text())
assert validation['status']=='passed'
assert validation['wallet-regressions']['passedTests']==265
assert validation['wallet-regressions']['failedTests']==0
assert validation['wallet-regressions']['skippedTests']==0
base='6b7e0bb4d4ec6fdaa96a9d014cea1aa86f3a760c'
def git(*args): return subprocess.check_output(['git','-C',str(source),*args])
assert git('rev-parse','HEAD').decode().strip()==base==validation['sourceRevision']
assert git('branch','--show-current').decode().strip()=='codex/ios-wallet-legacy-secret-recovery-20260908'
assert not git('diff','--cached','--name-only')
assert not git('ls-files','--others','--exclude-standard')
files=git('diff','--name-only').decode().splitlines(); assert len(files)==9
inventory={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in git('ls-files','-z').decode().split('\0') if n and (source/n).is_file()}
assert inventory==validation['sourceAtStart']==validation['sourceAtEnd']
subprocess.run(['git','-C',str(source),'diff','--check'],check=True)
subprocess.run(['git','-C',str(source),'add','--',*files],check=True)
subprocess.run(['git','-C',str(source),'commit','-m','Recover retained legacy entropy before first network activation'],check=True)
runtime=git('rev-parse','HEAD').decode().strip()
assert git('rev-list','--parents','-n','1','HEAD').decode().split()==[runtime,base]
assert not git('status','--porcelain=v1','--untracked-files=all')
output=root/'legacy-secret-recovery-evidence/runtime-commit-observation.json'; assert not output.exists()
output.write_text(json.dumps({'runtimeRevision':runtime,'parent':base,'validationReceipt':str(validation_path),'validationReceiptSha256':hashlib.sha256(validation_path.read_bytes()).hexdigest(),'files':files,'trackedFiles':len(inventory),'passedWalletTests':265,'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
print('Verified runtime commit: '+runtime,flush=True)
