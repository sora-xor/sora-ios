#!/usr/bin/env python3
"""Prepare final1402-R4 evidence helpers; execute no export/import/upload."""
import ast, datetime, hashlib, json, os, pathlib, subprocess
ROOT=pathlib.Path(__file__).resolve().parent
PREVIOUS=ROOT/'external-publication-2026091402-r3'
OUTPUT=ROOT/'external-publication-2026091402-r4'
SOURCE=ROOT/'publish-2026091402-ios-r4'
CANDIDATE=ROOT/'publication-candidate-preparation-2026091402-r4/candidate-observation.json'
NAMES=['verify-external-package.py','retain-external-upload.py','import-verified-archive-to-organizer.py','export-local-external-ipa-automatic.py','retain-symbol-warning-upload.py']
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(SOURCE),*args],text=True).strip()
def main():
    assert not OUTPUT.exists() and not OUTPUT.is_symlink(), 'Fresh output required'
    raw=CANDIDATE.read_bytes();candidate=json.loads(raw)
    assert candidate['status']=='candidate-pushed-validation-pending', 'Completed final candidate preparation required'
    publication=git('rev-parse','HEAD');runtime=git('rev-parse','HEAD^')
    assert publication==candidate['publicationRevision'] and runtime==candidate['runtimeRevision']
    assert git('rev-parse','@{upstream}')==publication and not git('status','--porcelain=v1','--untracked-files=all')
    previous_runtime_tree = subprocess.check_output(['git','-C',str(ROOT/'publish-2026091402-ios-r3'),'ls-tree','-r','390df8dd0504136a8b81a56d8aea5d00128b114f'],text=True)
    def tree_map(text):
        return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in text.splitlines()}
    old_tree=tree_map(previous_runtime_tree);new_tree=tree_map(git('ls-tree','-r',runtime))
    assert sorted(path for path in old_tree.keys()|new_tree.keys() if old_tree.get(path)!=new_tree.get(path))==['SoraPassport/Scripts/test-egyptian-localization.py'], 'Unexpected change to previously frozen runtime tree'
    prepared={};oldhashes={};previous=json.loads((PREVIOUS/'helper-preparation-observation.json').read_bytes())
    destination=pathlib.Path.home()/'Library/Developer/Xcode/Archives/0008-09-08/SORA-2026091402-r4.xcarchive'
    for name in NAMES:
        original=(PREVIOUS/name).read_bytes();oldhashes[name]=sha(original)
        assert oldhashes[name]==previous['preparedHelperSha256'][name]
        text=original.decode().replace('publish-2026091402-ios-r3','publish-2026091402-ios-r4')
        text=text.replace('57599f67d756c068e1d4ed602fbd75853b88fc87',publication).replace('390df8dd0504136a8b81a56d8aea5d00128b114f',runtime)
        text=text.replace('final1402 R3','final1402 R4')
        if name=='import-verified-archive-to-organizer.py':
            import re
            text,n=re.subn(r'^DESTINATION = .+$','DESTINATION = Path('+repr(str(destination))+')',text,count=1,flags=re.MULTILINE)
            assert n==1
        ast.parse(text);prepared[name]=text.encode()
    assert git('rev-parse','HEAD')==publication and not git('status','--porcelain=v1','--untracked-files=all')
    os.umask(0o077);OUTPUT.mkdir(mode=0o700)
    for name,data in prepared.items():
        with (OUTPUT/name).open('xb') as f:f.write(data)
        (OUTPUT/name).chmod(0o700)
    receipt={'observedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'helpers-reviewed-prepared-not-executed','buildNumber':'2026091402','sourceRevision':publication,'runtimeRevision':runtime,'sourceClean':True,'upstreamMatched':True,'candidateReceiptSHA256':sha(raw),'previousHelpers':str(PREVIOUS),'previousHelperSha256':oldhashes,'preparedHelperSha256':{n:sha(b) for n,b in prepared.items()},'nativeArchive':str(ROOT/'next-upload-2026091402-attempt-3/SORA-2026091402.xcarchive'),'organizerArchive':str(destination),'onlyChanges':'Final R4 pins/source path/description and fresh Organizer filename preserving R3; same unconsumed1402 build.','signingDistributionAndInputPreservationPoliciesUnchanged':True,'compiledRuntimeDeltaFromR3':[],'nonRuntimeTestDeltaFromR3':['SoraPassport/Scripts/test-egyptian-localization.py'],'canonicalValidation':'working-default-nodes-validation-2; checked separately before publication','releaseOperationsExecuted':[]}
    (OUTPUT/'helper-preparation-observation.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:receipt[k] for k in ['status','sourceRevision','runtimeRevision','nativeArchive','organizerArchive']},indent=2))
if __name__=='__main__':main()
