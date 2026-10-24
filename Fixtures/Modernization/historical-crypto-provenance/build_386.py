#!/usr/bin/env python3
"""Build a minimal host harness from the exact retained 3.8.6 dependency sources."""
import argparse
import json
from pathlib import Path
import subprocess
import tarfile
import io
from retarget_archive import retarget

parser = argparse.ArgumentParser()
parser.add_argument('--ssf', type=Path, required=True)
parser.add_argument('--checkouts', type=Path, required=True)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
p = Path(__file__).resolve().parent
s = args.ssf.resolve()
r = p / 'runtime' / '386'
r.mkdir(parents=True, exist_ok=True)
commands = []

def run(command, discard_stdout=False):
    command = list(map(str, command))
    commands.append(command)
    result = subprocess.run(command, stdout=subprocess.DEVNULL if discard_stdout else subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, errors='replace')
    with (p / 'build-386.log').open('a') as log:
        log.write((result.stdout or '') + result.stderr)
    (p / 'build-386-commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    if result.returncode:
        print(result.stderr[-6000:])
        raise SystemExit(result.returncode)
    return result.stdout or ''

# Export dependency revisions from existing Git objects; never use dirty checkout bytes.
for name, revision in [('BigInt', '793a7fac0bfc318e85994bf6900652e827aef33e'),
                       ('secp256k1.swift', 'cd187c632fb812fd93711a9f7e644adb7e5f97f0'),
                       ('tweetnacl-swiftwrap', 'f8fd111642bf2336b11ef9ea828510693106e954')]:
    output = r / name
    output.mkdir(exist_ok=True)
    archive = subprocess.check_output(['git', '-C', str(args.checkouts / name), 'archive', revision])
    with tarfile.open(fileobj=io.BytesIO(archive)) as t:
        t.extractall(output)

subpath = 'secp256k1/Classes/secp256k1'
subrepo = args.checkouts / 'secp256k1.swift' / subpath
subarchive = subprocess.check_output(['git', '-C', str(subrepo), 'archive', 'd5407179912e8c1f825a212a474aaa86b10f1352'])
with tarfile.open(fileobj=io.BytesIO(subarchive)) as t:
    t.extractall(r / 'secp256k1.swift' / subpath)

libraries = []
for name in ['libed25519', 'sr25519lib', 'blake2lib']:
    output = r / name
    source = s / 'Binaries' / (name + '.xcframework') / 'ios-arm64_x86_64-simulator' / (name + '.framework') / name
    libraries.append(output / 'macos.a' if (output / 'macos.a').exists() else retarget(source, output))

sec = r / 'secp256k1.swift/secp256k1/Classes/secp256k1'
secobj = r / 'secp256k1.o'
run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-O2', '-c',
     sec / 'src/secp256k1.c', '-I' + str(sec / 'include'), '-I' + str(sec / 'src'), '-o', secobj])

headers = s / 'Sources/IrohaCrypto/include'
module = r / 'IrohaCrypto'
module.mkdir(exist_ok=True)
selected_headers = [f for f in headers.glob('*.h') if f.name not in ('IrohaCrypto-umbrella.h', 'IRWordList.h', 'ed25519_export.h', 'sha512.h', 'sha256.h')]
(module / 'module.modulemap').write_text('module IrohaCrypto {\n' + '\n'.join('header "' + str(f) + '"' for f in selected_headers) + '\nexport *\n}\n')

objects = [secobj]
for name in ['crypto_scrypt', 'crypto_scrypt_smix', 'crypto_scrypt_smix_sse2', 'sha256', 'insecure_memzero', 'warnp']:
    obj = r / ('scrypt-' + name + '.o')
    run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-O2', '-c',
         s / 'Sources/scrypt' / (name + '.c'), '-I' + str(s / 'Sources/scrypt/include'), '-o', obj])
    objects.append(obj)
classes = s / 'Sources/IrohaCrypto/Classes'
for folder in ['Common', 'BIP39', 'sr25519', 'ed25519', 'secp256k1', 'blake2', 'ss58', 'Scrypt']:
    for source in (classes / folder).glob('*.m'):
        if source.name in ('IRSeedCreator.m', 'IRSeedCreator+BIP39.m', 'IRBIP39SeedCreator.m', 'IRSeedCreator+Scrypt.m'):
            continue
        obj = r / (source.stem + '.o')
        framework_args = []
        for name in ['libed25519', 'sr25519lib', 'blake2lib']:
            framework_args += ['-F' + str(s / 'Binaries' / (name + '.xcframework') / 'ios-arm64_x86_64-simulator')]
        run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-fobjc-arc', '-include', 'Security/Security.h',
             '-include', str(sec / 'include/secp256k1_recovery.h'),
             '-c', source, '-I' + str(headers), '-I' + str(sec / 'include'), '-I' + str(s / 'Sources/scrypt/include'), *framework_args, '-o', obj])
        objects.append(obj)
run(['xcrun', 'libtool', '-static', '-o', r / 'libIrohaCrypto.a', *objects, *libraries])
run(['xcrun', 'clang', '-dynamiclib', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-framework', 'Foundation',
     '-framework', 'Security', *objects, *libraries, '-install_name', '@rpath/libIrohaCrypto.dylib', '-o', r / 'libIrohaCrypto.dylib'])

swiftcommon = ['xcrun', 'swiftc', '-swift-version', '5', '-target', 'arm64-apple-macosx13.0', '-I', r, '-I', module,
               '-L', r, '-Xlinker', '-rpath', '-Xlinker', str(r)]
bigint = list((r / 'BigInt/Sources').glob('*.swift'))
run([*swiftcommon, '-emit-library', '-emit-module', '-module-name', 'BigInt', *bigint, '-o', r / 'libBigInt.dylib', '-emit-module-path', r / 'BigInt.swiftmodule'])

tweet = r / 'tweetnacl-swiftwrap/Sources'
tweetmodule = r / 'CTweetNacl'
tweetmodule.mkdir(exist_ok=True)
(tweetmodule / 'module.modulemap').write_text('module CTweetNacl { header "' + str(tweet / 'CTweetNacl/include/ctweetnacl.h') + '" export * }\n')
run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-O2', '-c', tweet / 'CTweetNacl/ctweetnacl.c',
     '-I' + str(tweet / 'CTweetNacl/include'), '-o', r / 'tweetnacl.o'])
run([*swiftcommon, '-I', tweetmodule, '-emit-library', '-emit-module', '-module-name', 'TweetNacl',
     *list((tweet / 'TweetNacl').glob('*.swift')), r / 'tweetnacl.o', '-o', r / 'libTweetNacl.dylib', '-emit-module-path', r / 'TweetNacl.swiftmodule'])
swiftcommon += ['-I', tweetmodule]
model = next((s / 'Sources/SSFModels').rglob('CryptoType.swift'))
run([*swiftcommon, '-emit-library', '-emit-module', '-module-name', 'SSFModels', model,
     '-o', r / 'libSSFModels.dylib', '-emit-module-path', r / 'SSFModels.swiftmodule'])

# The two Blake calls below are verbatim from historical Data+Hash.swift. Its
# unrelated xxHash functions are omitted to keep unrelated dependencies out.
(r / 'Data+Blake.swift').write_text('import Foundation\nimport IrohaCrypto\npublic extension Data {\n    func blake2b32() throws -> Data {\n        try (self as NSData).blake2b(32)\n    }\n}\n')
scale = s / 'Sources/SSFUtils/SSFUtils/Classes/Scale'
utils = [scale / 'ScaleCoding.swift', scale / 'Encodable/String+Scale.swift', scale / 'Encodable/BigInt+Scale.swift',
         s / 'Sources/SSFModels/SSFModels/Data+Hex.swift', r / 'Data+Blake.swift',
         s / 'Sources/SSFUtils/SSFUtils/Classes/Common/ChainType.swift', s / 'Sources/SSFUtils/SSFUtils/Classes/Common/Data+Random.swift',
         *list((s / 'Sources/SSFUtils/SSFUtils/Classes/Keystore').glob('*.swift'))]
run([*swiftcommon, '-lBigInt', '-lIrohaCrypto', '-lTweetNacl', '-lSSFModels', '-emit-library', '-emit-module', '-module-name', 'SSFUtils', *utils,
     '-o', r / 'libSSFUtils.dylib', '-emit-module-path', r / 'SSFUtils.swiftmodule'])

crypto = s / 'Sources/SSFCrypto/Classes/Keypair/Crypto'
files = [crypto / 'SeedFactory.swift', crypto / 'Data+Seed.swift', crypto / 'JunctionFactory/Chaincode.swift',
         crypto / 'JunctionFactory/JunctionFactory.swift', crypto / 'JunctionFactory/SubstrateJunctionFactory.swift',
         crypto / 'KeypairFactory/KeypairFactory.swift', crypto / 'KeypairFactory/SR25519KeypairFactory.swift',
         crypto / 'KeypairFactory/Ed25519KeypairFactory.swift', crypto / 'KeypairFactory/EcdsaKeypairFactory.swift']
run([*swiftcommon, '-lBigInt', '-lIrohaCrypto', '-lSSFUtils', '-emit-library', '-emit-module', '-module-name', 'SSFCrypto', *files,
     '-o', r / 'libSSFCrypto.dylib', '-emit-module-path', r / 'SSFCrypto.swiftmodule'])
if (p / 'generate_386.swift').exists():
    run([*swiftcommon, '-lBigInt', '-lIrohaCrypto', '-lSSFModels', '-lTweetNacl', '-lSSFUtils', '-lSSFCrypto', p / 'generate_386.swift', '-o', r / 'generate_386'])
    run([r / 'generate_386', args.output.resolve() if args.output else p / 'ios-386-vectors.json'], discard_stdout=True)
print('Historical 3.8.6 modules built successfully')
