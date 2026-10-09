#!/usr/bin/env python3
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'wallet-recovery-diagnostics-ios'
primary=root.parent/'sora-ios'
candidate=root/'publish-2026091302-ios'
runtime_record=json.loads((root/'wallet-recovery-diagnostics-evidence/runtime-commit-observation.json').read_text())
receipt=json.loads((root/'wallet-recovery-diagnostics-validation-1/run-observation.json').read_text())
assert receipt['status']=='passed'
assert receipt['sourceAtStart']==receipt['sourceAtEnd']
def git(path,*args): return subprocess.check_output(['git',*args],cwd=path)
def inventory(path):
    return {n:hashlib.sha256((path/n).read_bytes()).hexdigest() for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
assert inventory(source)==receipt['sourceAtEnd']
runtime=runtime_record['runtimeRevision']
assert runtime==git(candidate,'rev-parse','HEAD^').decode().strip()
patch=git(source,'diff','--binary','--full-index',receipt['sourceRevision'])
assert patch==git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime)
paths=set(git(source,'diff','--name-only',receipt['sourceRevision']).decode().splitlines())
assert paths == set(runtime_record['files'])
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
(root/'wallet-recovery-diagnostics-primary-integration.json').write_text(json.dumps(record,indent=2)+'\n')
(root/'wallet-recovery-diagnostics-runtime.patch').write_bytes(patch)
print('Integrated exact tested fix; unrelated files and index preserved')
