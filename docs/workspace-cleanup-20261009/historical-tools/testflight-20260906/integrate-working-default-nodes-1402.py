#!/usr/bin/env python3
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'working-default-nodes-ios'
primary=root.parent/'sora-ios'
candidate=root/'publish-2026091402-ios-r2'
runtime_record=json.loads((root/'working-default-nodes-evidence/runtime-commit-observation.json').read_text())
receipt=json.loads((root/'working-default-nodes-validation-1/run-observation.json').read_text())
assert receipt['status']=='passed'
assert {k:receipt['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')} == {'passedTests':296,'failedTests':0,'skippedTests':0}
assert receipt['sourceRevision']=='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'
assert runtime_record['validationReceiptSha256']==hashlib.sha256((root/'working-default-nodes-validation-1/run-observation.json').read_bytes()).hexdigest()
assert receipt['sourceAtStart']==receipt['sourceAtEnd']
def git(path,*args): return subprocess.check_output(['git',*args],cwd=path)
def inventory(path):
    return {n:hashlib.sha256((path/n).read_bytes()).hexdigest() for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
assert inventory(source)==receipt['sourceAtEnd']
runtime=runtime_record['runtimeRevision']
assert runtime=='bd2641aa55c8081b457316ed19f4cccbc0257313'
assert runtime_record['publicationRevision']=='5a362b31a27003695d0d90c787e603bc5b33ad24'==git(candidate,'rev-parse','HEAD').decode().strip()
assert git(candidate,'rev-parse','@{upstream}').decode().strip()=='5a362b31a27003695d0d90c787e603bc5b33ad24'
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
assert not (root/'working-default-nodes-primary-integration.json').exists()
assert not (root/'working-default-nodes-runtime.patch').exists()
assert runtime==git(candidate,'rev-parse','HEAD^').decode().strip()
patch=git(source,'diff','--binary','--full-index',receipt['sourceRevision'])
assert patch==git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime)
paths=set(git(source,'diff','--name-only',receipt['sourceRevision']).decode().splitlines())
assert paths == set(runtime_record['files'])
assert paths == {'SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewFactory.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainRegistry.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/NetworkAvailabilityLayer/NetworkAvailabilityLayerPresenter.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainSyncService.swift', 'SoraPassportTests/Common/Config/ApplicationConfigTests.swift', 'SoraPassport/Common/Configs/ApplicationConfigs.swift', 'SoraPassport/SoraLocalizable/ja.lproj/Localizable.strings', 'SoraPassport/ModulesRedesign/Pincode/PinSetup/PinSetupWireframe.swift', 'SoraPassport/Common/Services/ChainRegistry/ConnectionPool/ConnectionPool.swift', 'SoraPassport/ModulesRedesign/Nodes/NodesViewFactory.swift', 'SoraPassport/Common/Network/JSONRPC/ConnectionAutobalancing.swift', 'SoraPassport/SoraLocalizable/en.lproj/Localizable.strings', 'SoraPassport/Common/WalletContext/WalletContextFactory.swift'}
# Refuse overlapping edits in these exact fourteen files before changing primary.
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
(root/'working-default-nodes-primary-integration.json').write_text(json.dumps(record,indent=2)+'\n')
(root/'working-default-nodes-runtime.patch').write_bytes(patch)
print('Integrated exact tested fix; unrelated files and index preserved')
