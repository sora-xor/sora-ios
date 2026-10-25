#!/usr/bin/env python3
"""Verify the independently prepared exact candidate after full validation; leave source checkout frozen."""
import datetime, hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'working-default-nodes-ios'
candidate=root/'publish-2026091402-ios-r2'
validation_path=root/'working-default-nodes-validation-1/run-observation.json'
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
assert publication=='5a362b31a27003695d0d90c787e603bc5b33ad24' and runtime=='bd2641aa55c8081b457316ed19f4cccbc0257313'
assert git(candidate,'rev-list','--parents','-n','1',runtime).decode().split()==[runtime,base]
assert git(candidate,'rev-parse','@{upstream}').decode().strip()==publication
files=git(source,'diff','--name-only').decode().splitlines();assert set(files) == {'SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewFactory.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainRegistry.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/NetworkAvailabilityLayer/NetworkAvailabilityLayerPresenter.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainSyncService.swift', 'SoraPassportTests/Common/Config/ApplicationConfigTests.swift', 'SoraPassport/Common/Configs/ApplicationConfigs.swift', 'SoraPassport/SoraLocalizable/ja.lproj/Localizable.strings', 'SoraPassport/ModulesRedesign/Pincode/PinSetup/PinSetupWireframe.swift', 'SoraPassport/Common/Services/ChainRegistry/ConnectionPool/ConnectionPool.swift', 'SoraPassport/ModulesRedesign/Nodes/NodesViewFactory.swift', 'SoraPassport/Common/Network/JSONRPC/ConnectionAutobalancing.swift', 'SoraPassport/SoraLocalizable/en.lproj/Localizable.strings', 'SoraPassport/Common/WalletContext/WalletContextFactory.swift'}

inventory={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in git(source,'ls-files','-z').decode().split('\0') if n and (source/n).is_file()}
assert inventory==validation['sourceAtStart']==validation['sourceAtEnd']
patch=git(source,'diff','--binary','--full-index',base)
assert patch==git(candidate,'diff','--binary','--full-index',base,runtime)
assert set(git(candidate,'diff','--name-only',runtime,publication).decode().splitlines()) == {'SoraPassport/Scripts/verify-modernization-dependencies.sh', 'SoraPassport/Scripts/upload-ios-internal-testflight.sh', 'SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py', 'SoraPassport/Scripts/test-ios-internal-testflight-upload.py'}
candidate_receipt = root/'publication-candidate-preparation-2026091402-r2/candidate-observation.json'
assert hashlib.sha256(candidate_receipt.read_bytes()).hexdigest() == '5890f2ca6448e625caa32d270f864ba68adcd12d481ffc58b50411237cca5dc9'
prepared = json.loads(candidate_receipt.read_text())
assert prepared['runtimeRevision'] == runtime and prepared['publicationRevision'] == publication
assert prepared['passedPublicationTests'] == 8 and prepared['sourceInventoryAtStart'] == inventory
assert prepared['runtimePatchSHA256'] == hashlib.sha256(patch).hexdigest()
expected_counts = {'WalletModernizationTests':236,'WalletRecoveryCapabilityGateTests':11,'WalletRecoveryExporterTests':12,'WalletUXTests':26,'GoogleImportResponseTests':3,'ApplicationConfigTests':8}
assert validation['expectedSuiteCounts'] == expected_counts
for label in ('build','wallet-regressions','wallet-regressions-summary'):
    commands = [item for item in validation['commands'] if item['label'] == label]
    assert len(commands) == 1 and commands[0]['exitCode'] == 0 and commands[0].get('finishedAt') and commands[0]['cwd'] == str(source)
output=root/'working-default-nodes-evidence/runtime-commit-observation.json';assert not output.exists()
assert git(source,'rev-parse','HEAD').decode().strip()==base
assert not git(source,'diff','--cached','--name-only')
assert inventory=={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in inventory}
output.write_text(json.dumps({'runtimeRevision':runtime,'publicationRevision':publication,'parent':base,'validationReceipt':str(validation_path),'validationReceiptSha256':hashlib.sha256(validation_path.read_bytes()).hexdigest(),'files':files,'trackedFiles':len(inventory),'passedTests':296,'passedWalletTests':285, 'passedNodeTests':8,'passedGoogleImportTests':3,'candidatePreparationReceipt':str(candidate_receipt),'candidatePreparationReceiptSha256':'5890f2ca6448e625caa32d270f864ba68adcd12d481ffc58b50411237cca5dc9','createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Candidate prepared concurrently; independently verified after full validation and exact binary patch verification. Original source HEAD, index and working files remain unchanged.'},indent=2)+'\n')
print('Verified committed candidate runtime '+runtime+'; validation checkout unchanged',flush=True)
