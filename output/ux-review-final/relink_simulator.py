from pathlib import Path
import shlex,subprocess,shutil,plistlib
repo=Path('/Users/takemiyamakoto/dev/sora-wallet/sora-ios')
base=Path('/tmp/sora-wallet-ux-startup-dev')
source=Path('/tmp/sora-wallet-ux-dev-final/Build/Products/Debug-iphonesimulator/SoraPassportDev.app')
dest=base/'SoraPassportDev.app'
log=Path('/tmp/sora-wallet-ux-startup4-dev-build.log').read_text()
assert '** BUILD SUCCEEDED **' in log
shutil.copytree(source,dest,dirs_exist_ok=True)
lines=log.splitlines()
dylibIndex=next(i for i,s in enumerate(lines) if s.startswith('Ld ') and s.endswith("SoraPassportDev.app/SoraPassportDev.debug.dylib normal (in target 'SoraPassportDev' from project 'SoraPassport')"))
dylibArgs=shlex.split(lines[dylibIndex+2].strip())
dylibArgs[dylibArgs.index('-o')+1]=str(dest/'SoraPassportDev.debug.dylib')
with (base/'relink-debug-dylib.log').open('w') as output:
 subprocess.run(dylibArgs,cwd=repo,stdout=output,stderr=subprocess.STDOUT,check=True)
 subprocess.run(['codesign','--force','--sign','-',str(dest/'SoraPassportDev.debug.dylib')],stdout=output,stderr=subprocess.STDOUT,check=True)
index=next(i for i,s in enumerate(lines) if s.startswith('Ld ') and s.endswith("SoraPassportDev.app/SoraPassportDev normal (in target 'SoraPassportDev' from project 'SoraPassport')"))
args=shlex.split(lines[index+2].strip())
assert 'clang' in Path(args[0]).name
args[args.index('-o')+1]=str(dest/'SoraPassportDev')
plist=base/'simulator-entitlements.plist'
plist.write_bytes(plistlib.dumps({'application-identifier':'UXSIM12345.co.jp.soramitsu.sora.dev.flex','keychain-access-groups':['UXSIM12345.co.jp.soramitsu.sora.dev.flex'],'get-task-allow':True}))
args += ['-Xlinker','-sectcreate','-Xlinker','__TEXT','-Xlinker','__entitlements','-Xlinker',str(plist)]
with (base/'relink.log').open('w') as output:
 subprocess.run(args,cwd=repo,stdout=output,stderr=subprocess.STDOUT,check=True)
 subprocess.run(['codesign','--force','--sign','-',str(dest)],stdout=output,stderr=subprocess.STDOUT,check=True)
print(dest)
