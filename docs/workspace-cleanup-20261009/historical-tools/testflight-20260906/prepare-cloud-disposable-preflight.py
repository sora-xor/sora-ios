from pathlib import Path
import subprocess,json,hashlib,shutil,datetime
base=Path(__file__).parent
old=base/'wallet-recovery-diagnostics-evidence/focused-executable-preflight-1'
out=base/'wallet-cloud-recovery-evidence/focused-executable-preflight-1'
source=base/'wallet-cloud-recovery-ios'
out.mkdir(parents=True,exist_ok=False)
for name in ['DerivedData','Sources']:
 subprocess.run(['/bin/cp','-cR',str(old/name),str(out/name)],check=True)
for name in ['runtime-input-observation.json','input-observation.json','run-runtime-preflight.py','run-compile-link.py','run-focused-tests.py','copied-derived-data-vfs.json']:
 text=(old/name).read_text().replace(str(old),str(out))
 (out/name).write_text(text)
# Overlay every current app/test/fixture source, without changing dependency inputs.
paths=subprocess.check_output(['git','ls-files','-z'],cwd=source).decode().split('\0')
for p in paths:
 if p and (out/'Sources'/p).is_file() and (source/p).is_file():
  if hashlib.sha256((out/'Sources'/p).read_bytes()).digest()!=hashlib.sha256((source/p).read_bytes()).digest():shutil.copy2(source/p,out/'Sources'/p)
for p in (out/'DerivedData').rglob('*'):
 if p.is_file() and (p.suffix in ['.json','.resp','.modulemap','.SwiftFileList','.LinkFileList'] or p.name.endswith('FileList')):
  try:s=p.read_text()
  except UnicodeDecodeError:continue
  t=s.replace(str(old),str(out))
  if s!=t:p.write_text(t)
vfs=json.loads((out/'copied-derived-data-vfs.json').read_text())
vfs['roots'].append({'type':'directory-remap','name':str(old/'DerivedData'),'external-contents':str(out/'DerivedData')})
(out/'copied-derived-data-vfs.json').write_text(json.dumps(vfs))
for name in ['runtime-input-observation.json','input-observation.json']:
 j=json.loads((out/name).read_text());j['source']=str(source);j['scope']='Disposable cloud recovery compiler/executable preflight; not canonical validation or release authority.'
 j['testSourceHashes']={p:hashlib.sha256((source/p).read_bytes()).hexdigest() for p in paths if p and p.startswith('SoraPassportTests/') and (source/p).is_file()}
 (out/name).write_text(json.dumps(j,indent=2)+'\n')
profile='(version 1)\n(allow default)\n(deny file-write* '+ ' '.join('(subpath '+json.dumps(str(p))+')' for p in [old,source,base/'upgrade-retry-validation-1/DerivedData',base/'wallet-recovery-diagnostics-ios',base/'connected-wallet-recovery-ios'])+')\n'
(out/'isolated-inputs.sb').write_text(profile)
(out/'preparation-observation.json').write_text(json.dumps({'status':'prepared','at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':str(source),'prior_preflight_preserved':str(old),'copied':str(out),'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=source).decode().strip()},indent=2)+'\n')
print(out,flush=True)
