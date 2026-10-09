#!/usr/bin/env python3
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'google-import-pin-response-ios'
primary=root.parent/'sora-ios'
candidate=root/'publish-2026091401-ios-r2'
runtime_record=json.loads((root/'google-import-pin-response-evidence/runtime-commit-observation.json').read_text())
receipt=json.loads((root/'google-import-pin-response-validation-2/run-observation.json').read_text())
assert receipt['status']=='passed'
assert {k:receipt['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')} == {'passedTests':284,'failedTests':0,'skippedTests':0}
assert receipt['sourceRevision']=='e55774deff4d19818e006597cb65f748613256e0'
assert runtime_record['validationReceiptSha256']==hashlib.sha256((root/'google-import-pin-response-validation-2/run-observation.json').read_bytes()).hexdigest()
assert receipt['sourceAtStart']==receipt['sourceAtEnd']
def git(path,*args): return subprocess.check_output(['git',*args],cwd=path)
def inventory(path):
    return {n:hashlib.sha256((path/n).read_bytes()).hexdigest() for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
assert inventory(source)==receipt['sourceAtEnd']
runtime=runtime_record['runtimeRevision']
assert runtime=='3631769220a9c0b6aeb06592af79aacf329c095a'
assert runtime_record['publicationRevision']=='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'==git(candidate,'rev-parse','HEAD').decode().strip()
assert git(candidate,'rev-parse','@{upstream}').decode().strip()=='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
assert not (root/'google-import-pin-response-primary-integration.json').exists()
assert not (root/'google-import-pin-response-runtime.patch').exists()
assert runtime==git(candidate,'rev-parse','HEAD^').decode().strip()
patch=git(source,'diff','--binary','--full-index',receipt['sourceRevision'])
assert patch==git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime)
paths=set(git(source,'diff','--name-only',receipt['sourceRevision']).decode().splitlines())
assert paths == set(runtime_record['files'])
assert paths == {'SoraPassport/ModulesRedesign/Pincode/PincodeViewController.swift', 'SoraPassport/ModulesRedesign/Pincode/AuthorizationPresenter.swift', 'SoraPassport/ModulesRedesign/Pincode/InputPincodePresenter.swift', 'SoraPassportTests/Modules/OnboardingMain/OnboardingMainInteractorTests.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/SecurityLayer/SecurityLayerWireframe.swift', 'SoraPassport/ModulesRedesign/OnbordingMain/OnboardingMainPresenter.swift', 'SoraPassport/ModulesRedesign/Pincode/LocalAuthentification/LocalAuthInteractor.swift', 'SoraPassport/ModulesRedesign/SecurityLayer/SecurityLayerInteractor.swift'}
# Refuse overlapping edits in these exact nine files before changing primary.
for name in paths:
    assert (primary/name).read_bytes() == git(candidate,'show',receipt['sourceRevision']+':'+name), 'Primary contains overlapping changes: '+name
before=inventory(primary)
index=Path(git(primary,'rev-parse','--git-path','index').decode().strip())
if not index.is_absolute(): index=primary/index
index_before=hashlib.sha256(index.read_bytes()).hexdigest()
subprocess.run(['git','apply','--check','-'],cwd=primary,input=patch,check=True)
subprocess.run(['git','apply','-'],cwd=primary,input=patch,check=True)
after=inventory(primary)
assert set(before)==set(after)
assert all(after[n]==receipt['sourceAtEnd'][n] for n in paths)
assert all(before[n]==after[n] for n in before if n not in paths)
assert hashlib.sha256(index.read_bytes()).hexdigest()==index_before
record={'status':'integrated','runtime':runtime,'files':sorted(paths),'primaryBefore':before,'primaryAfter':after,'indexPreserved':True,'patchSha256':hashlib.sha256(patch).hexdigest()}
(root/'google-import-pin-response-primary-integration.json').write_text(json.dumps(record,indent=2)+'\n')
(root/'google-import-pin-response-runtime.patch').write_bytes(patch)
print('Integrated exact tested fix; unrelated files and index preserved')
