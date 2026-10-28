#!/usr/bin/env python3
"""Create a source-identical archive candidate while canonical validation runs.

This is explicitly not a passed-validation preparation or upload authority.
Original source HEAD, index, files and Git configuration remain untouched.
"""
from pathlib import Path
import datetime,hashlib,importlib.util,json,os,re,subprocess
ROOT=Path(__file__).resolve().parent
SOURCE=ROOT/'working-default-nodes-ios'
WORKTREE=ROOT/'publish-2026091402-ios-r3'
OUTPUT=ROOT/'publication-candidate-preparation-2026091402-r3'
REPOSITORY=OUTPUT/'candidate.git'
BASE='f8533a7c5ae2439192fdc2a1bb98f00fa29f1fd5'
BRANCH='codex/ios-wallet-upgrade-testflight-2026091402-r3'
VALIDATION=ROOT/'working-default-nodes-validation-2/run-observation.json'
REMOTE='https://github.com/sora-xor/sora-ios.git'
ENV=dict(os.environ,GIT_OPTIONAL_LOCKS='0')
def require(value,message):
 if not value:raise RuntimeError(message)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(path,*args):return subprocess.check_output(['/usr/bin/git','-C',str(path),*args],env=ENV)
def inventory(path):return {n:sha((path/n).read_bytes()) for n in git(path,'ls-files','-z').decode().split('\0') if n and (path/n).is_file()}
def metadata():
 gd=Path(git(SOURCE,'rev-parse','--absolute-git-dir').decode().strip());common=Path(git(SOURCE,'rev-parse','--path-format=absolute','--git-common-dir').decode().strip())
 paths={gd/'HEAD',gd/'index',gd/'config.worktree',common/'config'}
 return {str(p):sha(p.read_bytes()) if p.is_file() else None for p in paths}
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
require(not OUTPUT.exists() and not WORKTREE.exists(),'Fresh candidate output and worktree required')
require(git(SOURCE,'rev-parse','HEAD').decode().strip()==BASE,'Frozen source HEAD changed')
original_metadata=metadata();frozen=inventory(SOURCE);validation=json.loads(VALIDATION.read_bytes())
require(validation.get('sourceRevision')==BASE and validation.get('sourceAtStart')==frozen,'Frozen candidate differs from validation2 start inventory')
require(validation.get('status')=='running','This helper is solely for a pending-validation archive candidate')
patch=git(SOURCE,'diff','--binary','--full-index',BASE,'--')
changed=git(SOURCE,'diff','--name-only',BASE,'--').decode().splitlines();require(set(changed) == {'SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewFactory.swift', 'SoraPassport/Common/Services/ChainRegistry/ConnectionPool/ConnectionPool.swift', 'SoraPassport/SoraLocalizable/en.lproj/Localizable.strings', 'SoraPassport/ModulesRedesign/NetworkAvailabilityLayer/NetworkAvailabilityLayerPresenter.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainRegistry.swift', 'SoraPassport/Common/Configs/ApplicationConfigs.swift', 'SoraPassport/Common/Services/ChainRegistry/ChainSyncService.swift', 'SoraPassportTests/Common/Config/ApplicationConfigTests.swift', 'SoraPassportTests/Common/Modernization/WalletUXTests.swift', 'SoraPassport/ModulesRedesign/Nodes/NodesViewFactory.swift', 'SoraPassport/SoraLocalizable/ja.lproj/Localizable.strings', 'SoraPassport/Common/WalletContext/WalletContextFactory.swift', 'SoraPassport/Common/Network/JSONRPC/ConnectionAutobalancing.swift', 'SoraPassport/ModulesRedesign/Pincode/PinSetup/PinSetupWireframe.swift'}, 'Expected exact working-node/startup runtime paths')
require(not git(SOURCE,'diff','--cached','--name-only'),'Original index unexpectedly staged')
require(not git(SOURCE,'ls-files','--others','--exclude-standard'),'Original source has untracked files')
OUTPUT.mkdir(mode=0o700);(OUTPUT/'runtime.patch').write_bytes(patch)
record={'status':'preparing-pending-validation-candidate','startedAt':now(),'baseRevision':BASE,'source':str(SOURCE),'publicationWorktree':str(WORKTREE),'publicationBranch':BRANCH,'candidateRepository':str(REPOSITORY),'validationReceipt':str(VALIDATION),'validationStatusAtStart':validation['status'],'canonicalValidationPending':True,'sourceInventoryAtStart':frozen,'originalGitMetadataAtStart':original_metadata,'runtimePaths':changed,'runtimePatchSHA256':sha(patch),'commands':[],'scope':'Candidate commit/pins/push only. Full296 validation (wallet, Google import, startup and node suites) and final exact hashes remain required before upload/install. No device qualification, archive, export, upload or install performed.'}
def save():(OUTPUT/'candidate-observation.json').write_text(json.dumps(record,indent=2)+'\n')
def command(label,args,cwd=None):
 entry={'label':label,'arguments':args,'cwd':str(cwd) if cwd else str(ROOT),'startedAt':now()};record['commands'].append(entry);save()
 r=subprocess.run(args,cwd=cwd or ROOT,env=ENV,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);log=OUTPUT/(label+'.log');log.write_bytes(r.stdout);entry.update(exitCode=r.returncode,finishedAt=now(),log=str(log),logSHA256=sha(r.stdout));save();require(r.returncode==0,label+' failed; inspect retained log');return r.stdout
save()
try:
 # Transfer a self-contained object database; avoid extending the historical alternate-store chain.
 command('clone-candidate-repository',['/usr/bin/git','clone','--bare','--no-local',str(SOURCE),str(REPOSITORY)])
 command('configure-candidate-origin',['/usr/bin/git','--git-dir',str(REPOSITORY),'remote','set-url','origin',REMOTE])
 command('configure-candidate-fetch',['/usr/bin/git','--git-dir',str(REPOSITORY),'config','remote.origin.fetch','+refs/heads/*:refs/remotes/origin/*'])
 require(not subprocess.check_output(['/usr/bin/git','--git-dir',str(REPOSITORY),'for-each-ref','--format=%(refname)','refs/heads/'+BRANCH],env=ENV).strip(),'Candidate branch exists already')
 command('create-candidate-worktree',['/usr/bin/git','--git-dir',str(REPOSITORY),'worktree','add','-b',BRANCH,str(WORKTREE),BASE]);WORKTREE.chmod(SOURCE.stat().st_mode&0o777)
 command('apply-runtime-check',['/usr/bin/git','-C',str(WORKTREE),'apply','--check',str(OUTPUT/'runtime.patch')])
 command('apply-runtime',['/usr/bin/git','-C',str(WORKTREE),'apply',str(OUTPUT/'runtime.patch')])
 require(inventory(WORKTREE)==frozen,'Candidate runtime not byte-identical to frozen validation input')
 require(git(WORKTREE,'diff','--binary','--full-index',BASE,'--')==patch,'Candidate runtime patch differs')
 command('stage-runtime',['/usr/bin/git','-C',str(WORKTREE),'add','--',*changed])
 command('commit-runtime',['/usr/bin/git','-C',str(WORKTREE),'commit','-m','Use verified default nodes and resume wallet startup after authentication'])
 runtime=git(WORKTREE,'rev-parse','HEAD').decode().strip();require(git(WORKTREE,'rev-list','--parents','-n','1',runtime).decode().split()==[runtime,BASE],'Runtime parent differs');record['runtimeRevision']=runtime
 require(inventory(WORKTREE)==frozen and not git(WORKTREE,'status','--porcelain=v1','--untracked-files=all'),'Runtime commit not exact clean candidate')
 spec=importlib.util.spec_from_file_location('reviewed_pin_preparation',ROOT/'prepare-testflight-2026091301.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 module.BUILD='2026091402';module.LOWER_BOUND='2026091401';module.BRANCH=BRANCH
 module.TOKENS=('3631769220a9c0b6aeb06592af79aacf329c095a', 'origin/codex/ios-wallet-upgrade-testflight-2026091401-r2', '2026091401', '2026091305')
 rendered,pinpatch,pinchanges=module.render(WORKTREE,runtime);(OUTPUT/'publication-pins.patch').write_text(''.join(pinpatch));record['publicationFiles']=pinchanges;save()
 for name,raw in rendered.items():(WORKTREE/name).write_bytes(raw)
 expected=dict(frozen,**{name:sha(raw) for name,raw in rendered.items()})
 require(inventory(WORKTREE)==expected,'Publication candidate differs beyond fourpins')
 tests=command('publication-tests',['/usr/bin/python3','-B','-I','-S',str(WORKTREE/'SoraPassport/Scripts/test-ios-internal-testflight-upload.py')],WORKTREE)
 require(re.search(rb'(?m)^Ran 8 tests in .+$',tests) and re.search(rb'(?m)^OK$',tests),'Expected8passingpublicationtests')
 command('publication-contract-lint',['/bin/sh',str(WORKTREE/'SoraPassport/Scripts/upload-ios-internal-testflight.sh'),'--lint-contract'],WORKTREE)
 command('diff-check',['/usr/bin/git','-C',str(WORKTREE),'diff','--check'])
 require(set(git(WORKTREE,'diff','--name-only').decode().splitlines())==set(rendered),'Expected exactly4publicationpaths')
 command('stage-publication',['/usr/bin/git','-C',str(WORKTREE),'add','--',*rendered])
 command('commit-publication',['/usr/bin/git','-C',str(WORKTREE),'commit','-m','Prepare TestFlight build 2026091402 source pins'])
 publication=git(WORKTREE,'rev-parse','HEAD').decode().strip();record['publicationRevision']=publication
 require(git(WORKTREE,'rev-list','--parents','-n','1',publication).decode().split()==[publication,runtime],'Publication parent differs')
 require(inventory(WORKTREE)==expected and not git(WORKTREE,'status','--porcelain=v1','--untracked-files=all'),'Publication not exact clean candidate')
 require(inventory(SOURCE)==frozen and metadata()==original_metadata,'Frozen source or Git metadata changed')
 # Per-command normal credential workflow; no account/config change outside candidate.
 gh=subprocess.check_output(['/usr/bin/which','gh'],env=ENV,text=True).strip()
 command('push-publication',['/usr/bin/git','-C',str(WORKTREE),'-c','credential.helper=','-c','credential.https://github.com.helper=!'+gh+' auth git-credential','push','--set-upstream','origin',BRANCH])
 require(git(WORKTREE,'rev-parse','@{upstream}').decode().strip()==publication,'Candidate upstream differs')
 require(inventory(SOURCE)==frozen and metadata()==original_metadata,'Original source state changed')
 require(git(SOURCE,'rev-parse','HEAD').decode().strip()==BASE,'Original HEAD changed')
 require(inventory(WORKTREE)==expected and not git(WORKTREE,'status','--porcelain=v1','--untracked-files=all'),'Published candidate changed')
 record.update(status='candidate-pushed-validation-pending',finishedAt=now(),passedPublicationTests=8,publicationSourceClean=True,upstreamMatches=True,runtimeInventoryMatchesFrozenValidationInput=True,trackedFileCount=len(frozen),runtimeInventorySHA256=sha(json.dumps(frozen,sort_keys=True).encode()),originalGitMetadataAtEnd=metadata(),originalHeadUnchanged=True,originalIndexAndConfigurationUnchanged=True)
except BaseException as e:record.update(status='failed',failure=str(e),finishedAt=now());save();raise
save();print(json.dumps({k:record[k] for k in ['status','runtimeRevision','publicationRevision','passedPublicationTests','originalIndexAndConfigurationUnchanged']}),flush=True)
