#!/usr/bin/env python3
"""Run public historical fixtures through the normal development app on an owned simulator.

Source qualification only, never a substitute for the signed-IPA physical-device gate.
The UUID must identify a simulator named SORA-Codex-SimulatorMatrix, created for this run.
No app data or Keychain is read from another device.
"""
import argparse
import copy
import json
import hashlib
import shutil
import pathlib
import plistlib
import subprocess
import sys
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--udid', required=True)
parser.add_argument('--xctestrun', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
parser.add_argument('--cases', nargs='+', default=['vector-9'])
parser.add_argument('--bundle', choices=['co.jp.soramitsu.sora.dev','co.jp.soramitsu.sora'], default='co.jp.soramitsu.sora.dev')
parser.add_argument('--stage', choices=['all', 'prepare', 'ui', 'verify'], default='all')
args = parser.parse_args()
if args.stage != 'all' and any(case in ['two-reinstalls', 'erase-restore'] for case in args.cases):
    sys.exit('The two-reinstalls and erase-restore scenarios require --stage all so their lifecycle evidence is complete.')
if args.bundle != 'co.jp.soramitsu.sora.dev' and (args.stage != 'ui' or args.cases != ['fresh-import']):
    sys.exit('Production simulator bundle is UI-only fresh public phrase import; no fixture writes.')
args.xctestrun = args.xctestrun.resolve()
args.output = args.output.resolve()
args.output.mkdir(parents=True, exist_ok=True)
devices = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))['devices']
device = next((d for group in devices.values() for d in group if d['udid'] == args.udid), None)
if not device or device['name'] != 'SORA-Codex-SimulatorMatrix' or not device.get('isAvailable'):
    sys.exit('Refusing: UUID must be the available, disposable SORA-Codex-SimulatorMatrix device.')
base = plistlib.loads(args.xctestrun.read_bytes())
results_path = args.output / 'matrix-results.json'
results = json.loads(results_path.read_text()) if results_path.exists() else []

def command(cmd, log):
    started = time.time()
    with open(log, 'w') as stream:
        process = subprocess.Popen(cmd, stdout=stream, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=240)
        except subprocess.TimeoutExpired:
            subprocess.run(['sample', str(process.pid), '2', '-file', str(log)+'.sample.txt'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            process.terminate()
            try: process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            code = 124
            stream.write('\nHARNESS_TIMEOUT: Xcode did not finish within 240 seconds. Not a pass.\n')
    return {'exitCode': code, 'seconds': round(time.time()-started,2), 'log': str(log)}

def route(case):
    if case in ['reinstall','bound-reinstall','two-reinstalls','missing-db']: return 'welcome'
    if case in ['new-phone','fresh-import']: return 'onboarding'
    if case in ['one-x','entropy-only']: return 'legacy'
    if case in ['corrupt-db','pinless','preserved-return']: return 'recovery'
    return 'wallet'

def app_container():
    return pathlib.Path(subprocess.check_output(
        ['xcrun','simctl','get_app_container',args.udid,args.bundle,'data'], text=True).strip())

def host_app():
    host = pathlib.Path(base['SoraPassportTests']['TestHostPath'].replace('__TESTROOT__',str(args.xctestrun.parent)))
    for candidate in [host, *host.parents]:
        if candidate.name.endswith('.app'): return candidate
    raise RuntimeError('The test host must resolve to an app bundle')

def assert_owned_marker(container):
    if (container/'Documents/simulator-public-fixtures-only.marker').read_text() != args.udid:
        raise RuntimeError('Fixture marker does not authorize this simulator')

def reinstall_with_receipt(record):
    # A real app uninstall retains simulator Keychain, but no wallet filesystem
    # is copied. Only the public fixture receipt and ownership marker return.
    old = app_container()
    assert_owned_marker(old)
    evidence = {n:(old/'Documents'/n).read_bytes() for n in
                ['simulator-upgrade-fixture.json','simulator-public-fixtures-only.marker']}
    subprocess.run(['xcrun','simctl','uninstall',args.udid,args.bundle],check=True)
    subprocess.run(['xcrun','simctl','install',args.udid,str(host_app())],check=True)
    fresh = app_container()/'Documents'
    fresh.mkdir(parents=True,exist_ok=True)
    for name,data in evidence.items(): (fresh/name).write_bytes(data)
    record['actualUninstallReinstall'] = True
    record['actualUninstallCount'] = record.get('actualUninstallCount',0)+1

def erase_and_restore_fixture_files(record):
    # Explicitly a simulator filesystem restore. This does not exercise a
    # physical backup service or transfer device-only Keychain items.
    old = app_container()
    assert_owned_marker(old)
    subprocess.run(['xcrun','simctl','terminate',args.udid,args.bundle],
                   stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    snapshot = args.output/('erase-restore-public-app-data-'+str(time.time_ns()))
    snapshot.mkdir()
    relative = ['Documents', 'Library/Application Support/SORA', 'Library/Preferences/'+args.bundle+'.plist']
    copied = []
    for name in relative:
        source = old/name
        if not source.exists(): continue
        target = snapshot/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if source.is_dir(): shutil.copytree(source,target)
        else: shutil.copy2(source,target)
        copied.append(name)
    hashes = {str(f.relative_to(snapshot)):hashlib.sha256(f.read_bytes()).hexdigest()
              for f in snapshot.rglob('*') if f.is_file()}
    subprocess.run(['xcrun','simctl','shutdown',args.udid],check=True)
    subprocess.run(['xcrun','simctl','erase',args.udid],check=True)
    subprocess.run(['xcrun','simctl','boot',args.udid],check=True)
    subprocess.run(['xcrun','simctl','bootstatus',args.udid,'-b'],check=True)
    subprocess.run(['xcrun','simctl','install',args.udid,str(host_app())],check=True)
    fresh = app_container()
    for name in copied:
        source,target=snapshot/name,fresh/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if source.is_dir(): shutil.copytree(source,target,dirs_exist_ok=True)
        else: shutil.copy2(source,target)
    for name,digest in hashes.items():
        if hashlib.sha256((fresh/name).read_bytes()).hexdigest()!=digest:
            raise RuntimeError('Restored public app-data file does not match its snapshot: '+name)
    record['actualSimulatorErase'] = True
    record['restoreScope'] = 'simulator filesystem app-data restore only; not physical iCloud or device-only Keychain migration'
    record['restoredPublicFileSHA256'] = hashes
    record['snapshot'] = str(snapshot)

for case in args.cases:
    if not all(c.isalnum() or c == '-' for c in case): sys.exit('Invalid case identifier')
    run = copy.deepcopy(base)
    env = {'SORA_SIMULATOR_FIXTURES':'PUBLIC_FIXTURES_ONLY',
           'SORA_SIMULATOR_EXPECTED_UDID': args.udid,
           'SORA_SIMULATOR_CASE': case, 'SORA_SIMULATOR_ROUTE': route(case), 'SORA_SIMULATOR_APP_BUNDLE':args.bundle}
    fixture = None
    fixture_dir = pathlib.Path(__file__).resolve().parents[1] / 'SoraPassportTests/Common/Modernization/HistoricalCrypto'
    if case.startswith('vector-') or case.startswith('long-'):
        long = case.startswith('long-')
        index = int(case.split('-')[1])
        fixture = json.loads((fixture_dir / ('ios-386-long-phrases.json' if long else 'ios-386-vectors.json')).read_text())['vectors'][index]
    elif case in ['multi','model-v1','pinless','bound-reinstall','leftovers','unreachable-node','kill-firstlaunch','fresh-import','two-reinstalls','preserved-return']:
        fixture = json.loads((fixture_dir / 'ios-386-vectors.json').read_text())['vectors'][9]
    elif case in ['one-x','entropy-only']:
        fixture = json.loads((fixture_dir / 'ios-386-long-phrases.json').read_text())['vectors'][0]
    if fixture and len(fixture['phrase'].split()) >= 12:
        env.update({'SORA_SIMULATOR_REVEAL_PHRASE':'1', 'SORA_SIMULATOR_PUBLIC_PHRASE':fixture['phrase'], 'SORA_SIMULATOR_ADDRESS':fixture['address']})
    for key, value in run.items():
        if key.startswith('SoraPassport'):
            value.setdefault('EnvironmentVariables',{}).update(env)
            # A build-for-testing command may have selected the unit target. Each
            # explicit command below chooses precisely one test from its target.
            value.pop('OnlyTestIdentifiers',None)
            value.pop('SkipTestIdentifiers',None)
    run_path = args.xctestrun.with_name('SimulatorMatrix-' + args.udid + '-' + case + '.xctestrun')
    run_path.write_bytes(plistlib.dumps(run))
    record = {'case':case,'udid':args.udid,'route':route(case),
              'scope':'simulator-source-qualification','releaseAuthorized':False,'stages':{}}
    stages = [
        ('prepare','SoraPassportTests/WalletSimulatorUpgradeFixtureTests/testPreparePublicHistoricalState'),
        ('ui','SoraPassportUITests/WalletSimulatorUpgradeUITests/testNormalApplicationLaunchAfterHistoricalWriter'),
        ('verify','SoraPassportTests/WalletSimulatorUpgradeFixtureTests/testVerifyStateAfterNormalApplicationLaunch')]
    if case == 'two-reinstalls':
        stages = [stages[0], ('ui-first',stages[1][1]), ('verify-first',stages[2][1]),
                  ('ui-second',stages[1][1]), ('verify-second',stages[2][1])]
    for stage, selector in stages:
        if args.stage != 'all' and args.stage != stage: continue
        if case == 'two-reinstalls':
            phase = 'second-install' if stage.endswith('second') else 'first-install'
            for key,value in run.items():
                if key.startswith('SoraPassport'):
                    value.setdefault('EnvironmentVariables',{})['SORA_SIMULATOR_PHASE'] = phase
            run_path.write_bytes(plistlib.dumps(run))
        print(f'{case}: {stage}', flush=True)
        result_bundle = args.output / (case+'-'+stage+'-'+str(time.time_ns())+'.xcresult')
        cmd = ['xcodebuild','test-without-building','-xctestrun',str(run_path),
               '-destination','platform=iOS Simulator,id='+args.udid,
               '-parallel-testing-enabled','NO','-onlyUsePackageVersionsFromResolvedFile',
               '-collect-test-diagnostics','never',
               '-only-testing:'+selector,'-resultBundlePath',str(result_bundle)]
        outcome = command(cmd, args.output / (case+'-'+stage+'.log'))
        outcome['resultBundle'] = str(result_bundle)
        record['stages'][stage] = outcome
        receipt = app_container() / 'Documents/simulator-upgrade-fixture.json'
        if receipt.exists():
            # Public synthetic identity and byte hashes only. Keep each phase
            # before the next real erase/uninstall replaces the app container.
            copied_receipt = args.output / (case + '-' + stage + '-receipt.json')
            shutil.copy2(receipt, copied_receipt)
            outcome['publicFixtureReceipt'] = str(copied_receipt)
        results_path.write_text(json.dumps(results+[record],indent=2)+'\n')
        if outcome['exitCode'] != 0:
            print(json.dumps(record,indent=2),flush=True)
            sys.exit(outcome['exitCode'])
        if (stage == 'prepare' and case in ['reinstall','bound-reinstall','two-reinstalls']) or (stage == 'verify-first' and case == 'two-reinstalls'):
            reinstall_with_receipt(record)
        if stage == 'prepare' and case == 'erase-restore':
            erase_and_restore_fixture_files(record)
        results_path.write_text(json.dumps(results+[record],indent=2)+'\n')
        if stage == 'prepare' and case == 'kill-firstlaunch':
            subprocess.run(['xcrun','simctl','launch',args.udid,'co.jp.soramitsu.sora.dev'],check=True)
            time.sleep(0.05)
            subprocess.run(['xcrun','simctl','terminate',args.udid,'co.jp.soramitsu.sora.dev'],check=True)
            record['termination'] = 'simctl terminate requested 50ms after launch returned; no exact migration checkpoint claimed'
    results.append(record)
    results_path.write_text(json.dumps(results,indent=2)+'\n')
    print(f'{case}: passed selected stages',flush=True)
