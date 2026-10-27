#!/usr/bin/env python3
"""Verify the independently prepared exact candidate after full validation; leave source checkout frozen."""
import datetime, hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'working-default-nodes-ios'
candidate=root/'publish-2026091402-ios-r4'
validation_path=root/'working-default-nodes-validation-2/run-observation.json'
validation=json.loads(validation_path.read_text())
assert validation['status']=='passed'
assert {k:validation['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')}=={'passedTests':296,'failedTests':0,'skippedTests':0}
base='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'
def git(path,*args): return subprocess.check_output(['git','-C',str(path),*args])
assert git(source,'rev-parse','HEAD').decode().strip()==base==validation['sourceRevision']
assert git(source,'branch','--show-current').decode().strip()=='codex/ios-working-default-nodes-20260914'
assert not git(source,'diff','--cached','--name-only')
assert not git(source,'ls-files','--others','--exclude-standard')
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
publication=git(candidate,'rev-parse','HEAD').decode().strip()
runtime=git(candidate,'rev-parse','HEAD^').decode().strip()
assert publication=='7176228c4accc13d88217bd69de58be53c532a05' and runtime=='a6aaa77b194e77f77b4335d0502738b3625411db'
assert git(candidate,'rev-list','--parents','-n','1',runtime).decode().split()==[runtime,base]
assert git(candidate,'rev-parse','@{upstream}').decode().strip()==publication
files=git(source,'diff','--name-only').decode().splitlines();assert set(files) == {'SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewFactory.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainRegistry.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/NetworkAvailabilityLayer/NetworkAvailabilityLayerPresenter.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainSyncService.swift', 'SoraPassportTests/Common/Config/ApplicationConfigTests.swift', 'SoraPassport/Common/Configs/ApplicationConfigs.swift', 'SoraPassport/SoraLocalizable/ja.lproj/Localizable.strings', 'SoraPassport/ModulesRedesign/Pincode/PinSetup/PinSetupWireframe.swift', 'SoraPassport/Common/Services/ChainRegistry/ConnectionPool/ConnectionPool.swift', 'SoraPassport/ModulesRedesign/Nodes/NodesViewFactory.swift', 'SoraPassport/Common/Network/JSONRPC/ConnectionAutobalancing.swift', 'SoraPassport/SoraLocalizable/en.lproj/Localizable.strings', 'SoraPassport/Common/WalletContext/WalletContextFactory.swift'}

inventory={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in git(source,'ls-files','-z').decode().split('\0') if n and (source/n).is_file()}
assert inventory==validation['sourceAtStart']==validation['sourceAtEnd']
patch=git(source,'diff','--binary','--full-index',base)
assert patch==git(candidate,'diff','--binary','--full-index',base,runtime,'--',*files)
assert set(git(candidate,'diff','--name-only',runtime,publication).decode().splitlines()) == {'SoraPassport/Scripts/verify-modernization-dependencies.sh', 'SoraPassport/Scripts/upload-ios-internal-testflight.sh', 'SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py', 'SoraPassport/Scripts/test-ios-internal-testflight-upload.py'}
candidate_receipt = root/'publication-candidate-preparation-2026091402-r4/candidate-observation.json'
assert hashlib.sha256(candidate_receipt.read_bytes()).hexdigest() == '88d608a4743291a15ed3aec4b730ea60173a68f70ec91a4c059762c0ecaf6512'
prepared = json.loads(candidate_receipt.read_text())
assert prepared['runtimeRevision'] == runtime and prepared['publicationRevision'] == publication
assert prepared['passedPublicationTests'] == 8 and prepared['sourceInventoryAtStart'] == inventory
assert prepared['runtimePatchSHA256'] == hashlib.sha256(patch).hexdigest()
# Canonical app/test Swift and resources are exact; the only added source delta
# updates a Python localization test expectation and has its own16passing tests.
test_path='SoraPassport/Scripts/test-egyptian-localization.py'
delta=prepared['additionalNoncompiledTestDelta']
assert delta['path']==test_path and delta['passedTests']==16
assert set(git(candidate,'diff','--name-only',base,runtime).decode().splitlines())==set(files)|{test_path}
assert hashlib.sha256(git(candidate,'show',runtime+':'+test_path)).hexdigest()==delta['afterSHA256']
assert hashlib.sha256((source/test_path).read_bytes()).hexdigest()==delta['beforeSHA256']
assert hashlib.sha256(git(candidate,'diff','--binary','--full-index',base,runtime,'--',test_path)).hexdigest()==delta['patchSHA256']
assert hashlib.sha256(git(candidate,'diff','--binary','--full-index',base,runtime)).hexdigest()==prepared['finalRuntimePatchSHA256']
expected=dict(inventory);expected[test_path]=delta['afterSHA256']
for name,item in prepared['publicationFiles'].items():
    assert expected[name]==item['beforeSha256']
    expected[name]=item['afterSha256']
assert expected=={n:hashlib.sha256((candidate/n).read_bytes()).hexdigest() for n in git(candidate,'ls-files','-z').decode().split('\0') if n and (candidate/n).is_file()}
for label,count in [('egyptian-localization-tests',16),('publication-tests',8)]:
    commands=[c for c in prepared['commands'] if c['label']==label]
    assert len(commands)==1 and commands[0]['exitCode']==0
    command=commands[0];log=Path(command['log']).read_bytes()
    assert hashlib.sha256(log).hexdigest()==command['logSHA256']
    import re
    assert re.search(rb'(?m)^Ran '+str(count).encode()+rb' tests in .+$',log) and re.search(rb'(?m)^OK$',log)

expected_counts = {'WalletModernizationTests':236,'WalletRecoveryCapabilityGateTests':11,'WalletRecoveryExporterTests':12,'WalletUXTests':26,'GoogleImportResponseTests':3,'ApplicationConfigTests':8}
assert validation['expectedSuiteCounts'] == expected_counts
for label in ('build','wallet-regressions','wallet-regressions-summary'):
    commands = [item for item in validation['commands'] if item['label'] == label]
    assert len(commands) == 1 and commands[0]['exitCode'] == 0 and commands[0].get('finishedAt') and commands[0]['cwd'] == str(source)
output=root/'working-default-nodes-evidence/runtime-commit-observation.json';assert not output.exists()
assert git(source,'rev-parse','HEAD').decode().strip()==base
assert not git(source,'diff','--cached','--name-only')
assert inventory=={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in inventory}
output.write_text(json.dumps({'runtimeRevision':runtime,'publicationRevision':publication,'parent':base,'validationReceipt':str(validation_path),'validationReceiptSha256':hashlib.sha256(validation_path.read_bytes()).hexdigest(),'files':files+[test_path],'canonicalRuntimeFiles':files,'additionalNoncompiledTestDelta':delta,'passedLocalizationTests':16,'trackedFiles':len(inventory),'passedTests':296,'passedWalletTests':285, 'passedNodeTests':8,'passedGoogleImportTests':3,'candidatePreparationReceipt':str(candidate_receipt),'candidatePreparationReceiptSha256':'88d608a4743291a15ed3aec4b730ea60173a68f70ec91a4c059762c0ecaf6512','createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Candidate compiled sources and resources independently verified byte-identical to full canonical validation, with only an additional separately passing Python test expectation correction. Original source HEAD, index and working files remain unchanged.'},indent=2)+'\n')
print('Verified committed candidate runtime '+runtime+'; validation checkout unchanged',flush=True)
