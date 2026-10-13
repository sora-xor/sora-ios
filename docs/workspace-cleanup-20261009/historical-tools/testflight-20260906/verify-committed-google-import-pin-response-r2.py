#!/usr/bin/env python3
"""Verify the independently prepared exact candidate after full validation; leave source checkout frozen."""
import datetime, hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'google-import-pin-response-ios'
candidate=root/'publish-2026091401-ios-r2'
validation_path=root/'google-import-pin-response-validation-2/run-observation.json'
validation=json.loads(validation_path.read_text())
assert validation['status']=='passed'
assert {k:validation['wallet-regressions'][k] for k in ('passedTests','failedTests','skippedTests')}=={'passedTests':284,'failedTests':0,'skippedTests':0}
base='e55774deff4d19818e006597cb65f748613256e0'
def git(path,*args): return subprocess.check_output(['git','-C',str(path),*args])
assert git(source,'rev-parse','HEAD').decode().strip()==base==validation['sourceRevision']
assert git(source,'branch','--show-current').decode().strip()=='codex/ios-google-import-pin-response-20260914'
assert not git(source,'diff','--cached','--name-only')
assert not git(source,'ls-files','--others','--exclude-standard')
assert not git(candidate,'status','--porcelain=v1','--untracked-files=all')
publication=git(candidate,'rev-parse','HEAD').decode().strip()
runtime=git(candidate,'rev-parse','HEAD^').decode().strip()
assert publication=='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5' and runtime=='3631769220a9c0b6aeb06592af79aacf329c095a'
assert git(candidate,'rev-list','--parents','-n','1',runtime).decode().split()==[runtime,base]
assert git(candidate,'rev-parse','@{upstream}').decode().strip()==publication
files=git(source,'diff','--name-only').decode().splitlines();assert set(files) == {'SoraPassport/ModulesRedesign/Pincode/PincodeViewController.swift', 'SoraPassport/ModulesRedesign/Pincode/AuthorizationPresenter.swift', 'SoraPassport/ModulesRedesign/Pincode/InputPincodePresenter.swift', 'SoraPassportTests/Modules/OnboardingMain/OnboardingMainInteractorTests.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/SecurityLayer/SecurityLayerWireframe.swift', 'SoraPassport/ModulesRedesign/OnbordingMain/OnboardingMainPresenter.swift', 'SoraPassport/ModulesRedesign/Pincode/LocalAuthentification/LocalAuthInteractor.swift', 'SoraPassport/ModulesRedesign/SecurityLayer/SecurityLayerInteractor.swift'}

inventory={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in git(source,'ls-files','-z').decode().split('\0') if n and (source/n).is_file()}
assert inventory==validation['sourceAtStart']==validation['sourceAtEnd']
patch=git(source,'diff','--binary','--full-index',base)
assert patch==git(candidate,'diff','--binary','--full-index',base,runtime)
assert set(git(candidate,'diff','--name-only',runtime,publication).decode().splitlines()) == {'SoraPassport/Scripts/verify-modernization-dependencies.sh', 'SoraPassport/Scripts/upload-ios-internal-testflight.sh', 'SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py', 'SoraPassport/Scripts/test-ios-internal-testflight-upload.py'}
candidate_receipt = root/'publication-candidate-preparation-2026091401-r2/candidate-observation.json'
assert hashlib.sha256(candidate_receipt.read_bytes()).hexdigest() == '3b3a9d45f6a0958db5aa2ee52a3bb83e1cf1d177cc8d01070a3c9be6898aac84'
prepared = json.loads(candidate_receipt.read_text())
assert prepared['runtimeRevision'] == runtime and prepared['publicationRevision'] == publication
assert prepared['passedPublicationTests'] == 8 and prepared['sourceInventoryAtStart'] == inventory
assert prepared['runtimePatchSHA256'] == hashlib.sha256(patch).hexdigest()
expected_counts = {'WalletModernizationTests':236,'WalletRecoveryCapabilityGateTests':11,'WalletRecoveryExporterTests':12,'WalletUXTests':22,'GoogleImportResponseTests':3}
assert validation['expectedSuiteCounts'] == expected_counts
for label in ('build','wallet-regressions','wallet-regressions-summary'):
    commands = [item for item in validation['commands'] if item['label'] == label]
    assert len(commands) == 1 and commands[0]['exitCode'] == 0 and commands[0].get('finishedAt') and commands[0]['cwd'] == str(source)
output=root/'google-import-pin-response-evidence/runtime-commit-observation.json';assert not output.exists()
assert git(source,'rev-parse','HEAD').decode().strip()==base
assert not git(source,'diff','--cached','--name-only')
assert inventory=={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in inventory}
output.write_text(json.dumps({'runtimeRevision':runtime,'publicationRevision':publication,'parent':base,'validationReceipt':str(validation_path),'validationReceiptSha256':hashlib.sha256(validation_path.read_bytes()).hexdigest(),'files':files,'trackedFiles':len(inventory),'passedTests':284,'passedWalletTests':281,'passedGoogleImportTests':3,'candidatePreparationReceipt':str(candidate_receipt),'candidatePreparationReceiptSha256':'3b3a9d45f6a0958db5aa2ee52a3bb83e1cf1d177cc8d01070a3c9be6898aac84','createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Candidate prepared concurrently; independently verified after full validation and exact binary patch verification. Original source HEAD, index and working files remain unchanged.'},indent=2)+'\n')
print('Verified committed candidate runtime '+runtime+'; validation checkout unchanged',flush=True)
