#!/usr/bin/env python3
import datetime, hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'connected-wallet-recovery-ios'
validation_path=root/'connected-wallet-recovery-validation-5/run-observation.json'
validation=json.loads(validation_path.read_text())
assert validation['status']=='passed'
assert validation['wallet-regressions']['passedTests']==271
assert validation['wallet-regressions']['failedTests']==0
assert validation['wallet-regressions']['skippedTests']==0
base='6afa083015a02eb12b1dade16d5be26f40018f33'
def git(*args): return subprocess.check_output(['git','-C',str(source),*args])
assert git('rev-parse','HEAD').decode().strip()==base==validation['sourceRevision']
assert git('branch','--show-current').decode().strip()=='codex/ios-connected-wallet-recovery-20260913'
assert not git('diff','--cached','--name-only')
assert not git('ls-files','--others','--exclude-standard')
files=git('diff','--name-only').decode().splitlines(); assert len(files)==12
inventory={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in git('ls-files','-z').decode().split('\0') if n and (source/n).is_file()}
assert inventory==validation['sourceAtStart']==validation['sourceAtEnd']
subprocess.run(['git','-C',str(source),'diff','--check'],check=True)
subprocess.run(['git','-C',str(source),'add','--',*files],check=True)
subprocess.run(['git','-C',str(source),'commit','-m','Restore missing wallet keys and derive Taira accounts for retained mnemonics'],check=True)
runtime=git('rev-parse','HEAD').decode().strip()
assert git('rev-list','--parents','-n','1','HEAD').decode().split()==[runtime,base]
assert not git('status','--porcelain=v1','--untracked-files=all')
output=root/'connected-wallet-recovery-evidence/runtime-commit-observation.json'; assert not output.exists()
output.parent.mkdir(mode=0o700, exist_ok=True)
output.write_text(json.dumps({'runtimeRevision':runtime,'parent':base,'validationReceipt':str(validation_path),'validationReceiptSha256':hashlib.sha256(validation_path.read_bytes()).hexdigest(),'files':files,'trackedFiles':len(inventory),'passedWalletTests':271,'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
print('Verified runtime commit: '+runtime,flush=True)
