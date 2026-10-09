#!/usr/bin/env python3
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'wallet-backup-preservation-ios'
primary=root.parent/'sora-ios'
candidate=root/'publish-2026091305-ios-r2'
runtime_record=json.loads((root/'wallet-backup-preservation-evidence/runtime-commit-observation.json').read_text())
receipt=json.loads((root/'wallet-backup-preservation-validation-3/run-observation.json').read_text())
assert receipt['status']=='passed'
assert {k:receipt['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')} == {'passedTests':278,'failedTests':0,'skippedTests':0}
assert receipt['sourceRevision']=='f38dcd3002aeccd4d21f78b87fe8c7d5ee116ca6'
assert runtime_record['validationReceiptSha256']==hashlib.sha256((root/'wallet-backup-preservation-validation-3/run-observation.json').read_bytes()).hexdigest()
assert receipt['sourceAtStart']==receipt['sourceAtEnd']
def git(path,*args): return subprocess.check_output(['git',*args],cwd=path)
def inventory(path):
    return {n:hashlib.sha256((path/n).read_bytes()).hexdigest() for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
assert inventory(source)==receipt['sourceAtEnd']
runtime=runtime_record['runtimeRevision']
assert runtime=='ec3c07f2c6ffaddbfff8c2983a63214718c519a8'
assert runtime_record['publicationRevision']=='e55774deff4d19818e006597cb65f748613256e0'==git(candidate,'rev-parse','HEAD').decode().strip()
assert git(candidate,'rev-parse','@{upstream}').decode().strip()=='e55774deff4d19818e006597cb65f748613256e0'
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
assert not (root/'wallet-backup-preservation-primary-integration.json').exists()
assert not (root/'wallet-backup-preservation-runtime.patch').exists()
assert runtime==git(candidate,'rev-parse','HEAD^').decode().strip()
patch=git(source,'diff','--binary','--full-index',receipt['sourceRevision'])
assert patch==git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime)
paths=set(git(source,'diff','--name-only',receipt['sourceRevision']).decode().splitlines())
assert paths == set(runtime_record['files'])
assert paths == {'SoraPassport/Scripts/collect-ios-migration-evidence.py', 'SoraPassportTests/Common/Modernization/WalletModernizationTests.swift', 'SoraPassport/Scripts/test-ios-migration-evidence-collector.py', 'SoraPassport/ModulesRedesign/SetupPassword/SetupPasswordViewFactory.swift', 'SoraPassport/Common/Storage/SelectedWalletSettings.swift', 'SoraPassport/Common/Migration/StorageMigrator.swift', 'SoraPassport/Scripts/verify-modernization-dependencies.sh', 'SoraPassport/ModulesRedesign/SetupPassword/SetupPasswordPresenter.swift'}
before=inventory(primary)
index=Path(git(primary,'rev-parse','--git-path','index').decode().strip())
if not index.is_absolute(): index=primary/index
index_before=hashlib.sha256(index.read_bytes()).hexdigest()
subprocess.run(['git','apply','--check','-'],cwd=primary,input=patch,check=True)
subprocess.run(['git','apply','-'],cwd=primary,input=patch,check=True)
after=inventory(primary)
assert set(before)==set(after)
assert all(before[n]==after[n] for n in before if n not in paths)
assert hashlib.sha256(index.read_bytes()).hexdigest()==index_before
record={'status':'integrated','runtime':runtime,'files':sorted(paths),'primaryBefore':before,'primaryAfter':after,'indexPreserved':True,'patchSha256':hashlib.sha256(patch).hexdigest()}
(root/'wallet-backup-preservation-primary-integration.json').write_text(json.dumps(record,indent=2)+'\n')
(root/'wallet-backup-preservation-runtime.patch').write_bytes(patch)
print('Integrated exact tested fix; unrelated files and index preserved')
