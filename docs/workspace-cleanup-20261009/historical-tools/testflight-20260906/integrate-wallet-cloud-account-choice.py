#!/usr/bin/env python3
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'wallet-cloud-account-choice-ios'
primary=root.parent/'sora-ios'
candidate=root/'publish-2026091304-ios'
runtime_record=json.loads((root/'wallet-cloud-account-choice-evidence/runtime-commit-observation.json').read_text())
receipt=json.loads((root/'wallet-cloud-account-choice-validation-1/run-observation.json').read_text())
assert receipt['status']=='passed'
assert {k:receipt['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')} == {'passedTests':274,'failedTests':0,'skippedTests':0}
assert receipt['sourceRevision']=='6f7625b3d40b19b06166fa418ba2359731e1b2ef'
assert runtime_record['validationReceiptSha256']==hashlib.sha256((root/'wallet-cloud-account-choice-validation-1/run-observation.json').read_bytes()).hexdigest()
assert receipt['sourceAtStart']==receipt['sourceAtEnd']
def git(path,*args): return subprocess.check_output(['git',*args],cwd=path)
def inventory(path):
    return {n:hashlib.sha256((path/n).read_bytes()).hexdigest() for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
assert inventory(source)==receipt['sourceAtEnd']
runtime=runtime_record['runtimeRevision']
assert runtime=='a472679a10beb1cc71468bcf25d7f57ac541c744'
assert runtime_record['publicationRevision']=='f38dcd3002aeccd4d21f78b87fe8c7d5ee116ca6'==git(candidate,'rev-parse','HEAD').decode().strip()
assert git(candidate,'rev-parse','@{upstream}').decode().strip()=='f38dcd3002aeccd4d21f78b87fe8c7d5ee116ca6'
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
assert not (root/'wallet-cloud-account-choice-primary-integration.json').exists()
assert not (root/'wallet-cloud-account-choice-runtime.patch').exists()
assert runtime==git(candidate,'rev-parse','HEAD^').decode().strip()
patch=git(source,'diff','--binary','--full-index',receipt['sourceRevision'])
assert patch==git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime)
paths=set(git(source,'diff','--name-only',receipt['sourceRevision']).decode().splitlines())
assert paths == set(runtime_record['files'])
assert paths == {'SoraPassport/Common/Storage/SelectedWalletSettings.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassportTests/Common/Modernization/WalletModernizationTests.swift', 'SoraPassport/ModulesRedesign/Root/RootWireframe.swift'}
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
(root/'wallet-cloud-account-choice-primary-integration.json').write_text(json.dumps(record,indent=2)+'\n')
(root/'wallet-cloud-account-choice-runtime.patch').write_bytes(patch)
print('Integrated exact tested fix; unrelated files and index preserved')
