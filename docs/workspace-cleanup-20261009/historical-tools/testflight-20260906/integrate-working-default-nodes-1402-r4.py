#!/usr/bin/env python3
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'working-default-nodes-ios'
primary=root.parent/'sora-ios'
candidate=root/'publish-2026091402-ios-r4'
runtime_record=json.loads((root/'working-default-nodes-evidence/runtime-commit-observation.json').read_text())
receipt=json.loads((root/'working-default-nodes-validation-2/run-observation.json').read_text())
assert receipt['status']=='passed'
assert {k:receipt['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')} == {'passedTests':296,'failedTests':0,'skippedTests':0}
assert receipt['sourceRevision']=='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'
assert runtime_record['validationReceiptSha256']==hashlib.sha256((root/'working-default-nodes-validation-2/run-observation.json').read_bytes()).hexdigest()
assert receipt['sourceAtStart']==receipt['sourceAtEnd']
def git(path,*args): return subprocess.check_output(['git',*args],cwd=path)
def inventory(path):
    return {n:hashlib.sha256((path/n).read_bytes()).hexdigest() for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
assert inventory(source)==receipt['sourceAtEnd']
runtime=runtime_record['runtimeRevision']
assert runtime=='a6aaa77b194e77f77b4335d0502738b3625411db'
assert runtime_record['publicationRevision']=='7176228c4accc13d88217bd69de58be53c532a05'==git(candidate,'rev-parse','HEAD').decode().strip()
assert git(candidate,'rev-parse','@{upstream}').decode().strip()=='7176228c4accc13d88217bd69de58be53c532a05'
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
assert not (root/'working-default-nodes-primary-integration.json').exists()
assert not (root/'working-default-nodes-runtime.patch').exists()
assert runtime==git(candidate,'rev-parse','HEAD^').decode().strip()
patch=git(source,'diff','--binary','--full-index',receipt['sourceRevision'])
canonical_paths=git(source,'diff','--name-only',receipt['sourceRevision']).decode().splitlines()
assert patch==git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime,'--',*canonical_paths)
assert runtime_record['passedLocalizationTests']==16
patch=git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime)
release_paths=set(git(candidate,'diff','--name-only',receipt['sourceRevision'],runtime).decode().splitlines())
assert release_paths == set(runtime_record['files'])
release_only_test='SoraPassport/Scripts/test-egyptian-localization.py'
assert not (primary/release_only_test).exists(), 'Expected release-only Python test absent from primary'
assert release_paths == set(canonical_paths) | {release_only_test}
paths=set(canonical_paths)
patch=git(candidate,'diff','--binary','--full-index',receipt['sourceRevision'],runtime,'--',*sorted(paths))
assert paths - {'SoraPassport/Scripts/test-egyptian-localization.py'} == {'SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewFactory.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainRegistry.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/NetworkAvailabilityLayer/NetworkAvailabilityLayerPresenter.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainSyncService.swift', 'SoraPassportTests/Common/Config/ApplicationConfigTests.swift', 'SoraPassport/Common/Configs/ApplicationConfigs.swift', 'SoraPassport/SoraLocalizable/ja.lproj/Localizable.strings', 'SoraPassport/ModulesRedesign/Pincode/PinSetup/PinSetupWireframe.swift', 'SoraPassport/Common/Services/ChainRegistry/ConnectionPool/ConnectionPool.swift', 'SoraPassport/ModulesRedesign/Nodes/NodesViewFactory.swift', 'SoraPassport/Common/Network/JSONRPC/ConnectionAutobalancing.swift', 'SoraPassport/SoraLocalizable/en.lproj/Localizable.strings', 'SoraPassport/Common/WalletContext/WalletContextFactory.swift'}
# Preserve the observed pre-existing empty localization key. The release's
# English patch only appends new strings; all existing primary bytes survive.
english = 'SoraPassport/SoraLocalizable/en.lproj/Localizable.strings'
expected_primary = {}
for name in paths:
    existing = (primary/name).read_bytes()
    baseline = git(candidate,'show',receipt['sourceRevision']+':'+name)
    tested = git(candidate,'show',runtime+':'+name)
    if name == english:
        assert hashlib.sha256(existing).hexdigest() == 'b221efd80078300c70e03eea42555b001a15b7a8ced6c68d33a50c092198624c', 'Existing English localization changed'
        assert existing.replace(b'"" = "";\n', b'', 1) == baseline
        assert tested.startswith(baseline), 'English release patch is not append-only'
        expected_primary[name] = hashlib.sha256(existing + tested[len(baseline):]).hexdigest()
    else:
        assert existing == baseline, 'Primary contains overlapping changes: '+name
        expected_primary[name] = hashlib.sha256(tested).hexdigest()
before=inventory(primary)
index=Path(git(primary,'rev-parse','--git-path','index').decode().strip())
if not index.is_absolute(): index=primary/index
index_before=hashlib.sha256(index.read_bytes()).hexdigest()
subprocess.run(['git','apply','--check','-'],cwd=primary,input=patch,check=True)
subprocess.run(['git','apply','-'],cwd=primary,input=patch,check=True)
after=inventory(primary)
assert set(before)==set(after)
assert all(after[n]==expected_primary[n] for n in paths)
assert all(before[n]==after[n] for n in before if n not in paths)
assert hashlib.sha256(index.read_bytes()).hexdigest()==index_before
record={'status':'integrated','runtime':runtime,'files':sorted(paths),'releaseOnlyPythonTestCorrection':runtime_record['additionalNoncompiledTestDelta'],'releaseOnlyPythonTestAbsentFromPrimary':True,'primaryBefore':before,'primaryAfter':after,'indexPreserved':True,'preservedExistingEnglishLocalizationKey':True,'expectedPrimaryTargetHashes':expected_primary,'patchSha256':hashlib.sha256(patch).hexdigest()}
(root/'working-default-nodes-primary-integration.json').write_text(json.dumps(record,indent=2)+'\n')
(root/'working-default-nodes-runtime.patch').write_bytes(patch)
print('Integrated exact tested fix; unrelated files and index preserved')
