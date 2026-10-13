#!/usr/bin/env python3
"""Prepare final1402-R3 evidence helpers only; perform no export/import/upload."""
import ast, datetime, hashlib, json, os, pathlib, subprocess
ROOT=pathlib.Path(__file__).resolve().parent
PREVIOUS=ROOT/'external-publication-2026091402-r2'
OUTPUT=ROOT/'external-publication-2026091402-r3'
SOURCE=ROOT/'publish-2026091402-ios-r3'
CANDIDATE=ROOT/'publication-candidate-preparation-2026091402-r3/candidate-observation.json'
NAMES=['verify-external-package.py','retain-external-upload.py','import-verified-archive-to-organizer.py','export-local-external-ipa-automatic.py','retain-symbol-warning-upload.py']
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(SOURCE),*args],text=True).strip()
def main():
    assert not OUTPUT.exists() and not OUTPUT.is_symlink(), 'Fresh output required'
    raw=CANDIDATE.read_bytes();candidate=json.loads(raw)
    publication=git('rev-parse','HEAD');runtime=git('rev-parse','HEAD^')
    assert publication==candidate['publicationRevision']=='57599f67d756c068e1d4ed602fbd75853b88fc87'
    assert runtime==candidate['runtimeRevision']=='390df8dd0504136a8b81a56d8aea5d00128b114f'
    assert git('rev-parse','@{upstream}')==publication and not git('status','--porcelain=v1','--untracked-files=all')
    prepared={};oldhashes={}
    previous_review=json.loads((PREVIOUS/'helper-review-observation.json').read_bytes())
    for name in NAMES:
        original=(PREVIOUS/name).read_bytes();oldhashes[name]=sha(original)
        assert oldhashes[name]==previous_review['helpers'][name]['sha256']
        text=original.decode().replace('publish-2026091402-ios-r2','publish-2026091402-ios-r3')
        text=text.replace('5a362b31a27003695d0d90c787e603bc5b33ad24',publication).replace('bd2641aa55c8081b457316ed19f4cccbc0257313',runtime)
        text=text.replace('final1402 R2','final1402 R3')
        ast.parse(text);prepared[name]=text.encode()
    assert git('rev-parse','HEAD')==publication and not git('status','--porcelain=v1','--untracked-files=all')
    os.umask(0o077);OUTPUT.mkdir(mode=0o700)
    for name,data in prepared.items():
        with (OUTPUT/name).open('xb') as f:f.write(data)
        (OUTPUT/name).chmod(0o700)
    receipt={'observedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'helpers-reviewed-prepared-not-executed','buildNumber':'2026091402','sourceRevision':publication,'runtimeRevision':runtime,'sourceClean':True,'upstreamMatched':True,'candidateReceiptSHA256':sha(raw),'previousHelpers':str(PREVIOUS),'previousHelperSha256':oldhashes,'preparedHelperSha256':{n:sha(b) for n,b in prepared.items()},'nativeArchive':str(ROOT/'next-upload-2026091402-attempt-2/SORA-2026091402.xcarchive'),'organizerArchive':str(pathlib.Path.home()/'Library/Developer/Xcode/Archives/0008-09-08/SORA-2026091402.xcarchive'),'onlyChanges':'Final R3 publication/runtime pins, publication source path, and fixed R3 description; same unconsumed1402 build.','signingDistributionAndInputPreservationPoliciesUnchanged':True,'canonicalValidation':'working-default-nodes-validation-2; pending at helper preparation','releaseOperationsExecuted':[]}
    (OUTPUT/'helper-preparation-observation.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:receipt[k] for k in ['status','sourceRevision','runtimeRevision','nativeArchive']},indent=2))
if __name__=='__main__':main()
