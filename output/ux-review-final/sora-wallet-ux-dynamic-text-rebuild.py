from pathlib import Path
import shlex, subprocess, shutil, concurrent.futures
repo=Path('/Users/takemiyamakoto/dev/sora-wallet/sora-ios')
def run_recorded(lines, match, out):
 for i,line in enumerate(lines):
  if not match(line): continue
  args=shlex.split(lines[i+2].strip())
  if args[:2]==['builtin-SwiftDriver','--']: args=args[2:]
  cwd=shlex.split(lines[i+1].strip())[1]
  out.write('\n'+line+'\n');out.flush()
  subprocess.run(args,cwd=cwd,stdout=out,stderr=subprocess.STDOUT,check=True)
def copy_modules(root, module):
 products=root/'Build/Products/Debug-iphonesimulator'
 for folder in (root/'Build/Intermediates.noindex').glob(f'*.build/Debug-iphonesimulator/{module}.build/Objects-normal/*'):
  arch=folder.name
  for suffix in ['swiftmodule','swiftdoc','abi.json']:
   src=folder/f'{module}.{suffix}'
   if src.exists(): shutil.copy2(src,products/f'{module}.swiftmodule/{arch}-apple-ios-simulator.{suffix}')
def build(dev):
 label='dev' if dev else 'main'
 root=Path('/tmp/sora-wallet-ux-dev-final' if dev else '/tmp/sora-wallet-ux-derived')
 package=Path('/tmp/sora-wallet-ux-final-dev-build.log' if dev else '/tmp/sora-wallet-ux-ios-tests.log').read_text().splitlines()
 app=Path('/tmp/sora-wallet-ux-startup4-dev-build.log' if dev else '/tmp/sora-wallet-ux-normal-ui-tests.log').read_text().splitlines()
 name='SoraPassportDev' if dev else 'SoraPassport'
 with open(f'/tmp/sora-wallet-ux-dynamic-text-{label}-rebuild.log','w') as out:
  run_recorded(package,lambda s:s.startswith('SwiftDriver SoraUIKit normal'),out)
  run_recorded(package,lambda s:s.startswith('Ld ') and 'SoraUIKit.o normal' in s,out)
  run_recorded(package,lambda s:s.startswith('CreateUniversalBinary ') and '/SoraUIKit.o ' in s,out)
  copy_modules(root,'SoraUIKit')
  run_recorded(app,lambda s:s.startswith(f'SwiftDriver {name} normal arm64 '),out)
  copy_modules(root,name)
  run_recorded(app,lambda s:s.startswith('Ld ') and (s.endswith(f'{name}.app/{name}.debug.dylib normal (in target \'{name}\' from project \'SoraPassport\')') or s.endswith(f'{name}.app/{name} normal (in target \'{name}\' from project \'SoraPassport\')')),out)
  if not dev:
   tests=Path('/tmp/sora-wallet-ux-startup4-tests.log').read_text().splitlines()
   run_recorded(tests,lambda s:s.startswith('SwiftDriver SoraPassportTests normal arm64 '),out)
   run_recorded(tests,lambda s:s.startswith('Ld ') and 'SoraPassportTests.xctest/SoraPassportTests normal' in s,out)
  out.write('\nRECORDED COMPILER/LINKER COMMANDS SUCCEEDED\n')
 return label
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for result in pool.map(build,[False,True]): print(result+' rebuilt',flush=True)
subprocess.run(['python3','/tmp/sora-wallet-ux-startup-dev/relink_simulator.py'],check=True)
