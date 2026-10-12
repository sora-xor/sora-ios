#!/usr/bin/env python3
"""Execute all three app-pinned FearlessUtils families with their original pods."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import tarfile
from retarget_archive import retarget

parser = argparse.ArgumentParser()
parser.add_argument('--checkouts', type=Path, required=True)
args = parser.parse_args()
p = Path(__file__).resolve().parent
r = p / 'runtime' / 'fearless-build'
r.mkdir(parents=True, exist_ok=True)
commands = []
pins = ['c1d17ccfbd8217612fdb56e588b1dec9cbe23bf5', 'e6aaeb177713793c18902d45e4e8264b8734665b',
        '26dfc128d0d1f35aac0c44ffab3ef1f2071e003c']

def run(command, discard_stdout=False):
    command = list(map(str, command))
    commands.append(command)
    result = subprocess.run(command, stdout=subprocess.DEVNULL if discard_stdout else subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, errors='replace')
    with (p / 'build-fearless.log').open('a') as log:
        log.write((result.stdout or '') + result.stderr)
    (p / 'build-fearless-commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    if result.returncode:
        print(result.stderr[-6000:])
        raise SystemExit(result.returncode)

def archive(repo, revision, destination):
    destination.mkdir(parents=True, exist_ok=True)
    data = subprocess.check_output(['git', '-C', str(repo), 'archive', revision])
    with tarfile.open(fileobj=io.BytesIO(data)) as contents:
        contents.extractall(destination)

for name, revision in [('BigInt', 'e1f28276687d7661cbb2754771bd9fc281784e32'),
                       ('tweetnacl-swiftwrap', 'd1552db4d907f2c5cb3d1bf1336496b2e16c8ecf')]:
    archive(args.checkouts / name, revision, r / name)
for name, revision in [('IrohaCrypto-0.9.0', '4033eb8d3f2e126bb7503757a4c0e701c121a8bb'),
                       ('secp256k1.c-0.1.2', '9b7e183c6515f69c1d0238573af6a93bd32fcb18'),
                       ('scrypt.c-0.1.1', '0a1ac944808cd667a0c2e2457a4729dcdd447085')]:
    archive(p / name, revision, r / name)
old = r / 'IrohaCrypto-0.9.0'
libraries = []
for source, name in [('sr25519Imp/libsr25519crust.a', 'sr25519'), ('ed25519Imp/libed25519_sha2.a', 'ed25519'),
                     ('blake2Imp/libblake2.a', 'blake2')]:
    destination = r / name
    libraries.append(destination / 'macos.a' if (destination / 'macos.a').exists() else retarget(old / source, destination))

sec = r / 'secp256k1.c-0.1.2/secp256k1'
scrypt = r / 'scrypt.c-0.1.1/scrypt'
# CocoaPods public-header layout, without modifying a historical header.
public = r / 'pod-headers'
(public / 'secp256k1').mkdir(parents=True, exist_ok=True)
for header in (sec / 'include').glob('*.h'):
    target = public / 'secp256k1' / header.name
    if not target.exists(): target.symlink_to(header)
objects = []
for source in [sec / 'secp256k1.c', *[scrypt / (name + '.c') for name in
               ['crypto_scrypt', 'crypto_scrypt_smix', 'crypto_scrypt_smix_sse2', 'sha256', 'insecure_memzero', 'warnp']]]:
    obj = r / (source.parent.name + '-' + source.stem + '.o')
    run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-O3', '-include', 'sys/types.h', '-c', source,
         '-I' + str(sec / 'include'), '-I' + str(scrypt / 'include'), '-o', obj])
    objects.append(obj)
classes = old / 'IrohaCrypto/Classes'
headerdirs = sorted({header.parent for root in [classes, old / 'sr25519Imp', old / 'ed25519Imp', old / 'blake2Imp'] for header in root.rglob('*.h')})
headerargs = ['-I' + str(folder) for folder in headerdirs] + ['-I' + str(public), '-I' + str(scrypt / 'include')]
for folder in ['Common', 'BIP39', 'Scrypt', 'sr25519', 'ed25519', 'secp256k1', 'blake2', 'ss58']:
    for source in (classes / folder).glob('*.m'):
        obj = r / (source.stem + '.o')
        run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-fobjc-arc',
             '-include', 'Security/Security.h', '-c', source, *headerargs, '-o', obj])
        objects.append(obj)
run(['xcrun', 'clang', '-dynamiclib', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-framework', 'Foundation',
     '-framework', 'Security', *objects, *libraries, '-install_name', '@rpath/libIrohaCrypto.dylib', '-o', r / 'libIrohaCrypto.dylib'])
module = r / 'IrohaCrypto'
module.mkdir(exist_ok=True)
headers = [header for header in classes.rglob('*.h') if header.name != 'IRWordList.h']
(module / 'module.modulemap').write_text('module IrohaCrypto {\n' + '\n'.join('header "' + str(h) + '"' for h in headers) + '\nexport *\n}\n')
swift = ['xcrun', 'swiftc', '-swift-version', '5', '-target', 'arm64-apple-macosx13.0', '-I', r, '-I', module,
         '-L', r, '-Xlinker', '-rpath', '-Xlinker', r]
for include in headerargs:
    swift += ['-Xcc', include]
run([*swift, '-emit-library', '-emit-module', '-module-name', 'BigInt', *list((r / 'BigInt/Sources').glob('*.swift')),
     '-o', r / 'libBigInt.dylib', '-emit-module-path', r / 'BigInt.swiftmodule'])
tweet = r / 'tweetnacl-swiftwrap/Sources'
tweetmodule = r / 'CTweetNacl'
tweetmodule.mkdir(exist_ok=True)
(tweetmodule / 'module.modulemap').write_text('module CTweetNacl { header "' + str(tweet / 'CTweetNacl/include/ctweetnacl.h') + '" export * }\n')
run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=13.0', '-O2', '-c', tweet / 'CTweetNacl/ctweetnacl.c',
     '-I' + str(tweet / 'CTweetNacl/include'), '-o', r / 'tweetnacl.o'])
run([*swift, '-I', tweetmodule, '-emit-library', '-emit-module', '-module-name', 'TweetNacl',
     *list((tweet / 'TweetNacl').glob('*.swift')), r / 'tweetnacl.o', '-o', r / 'libTweetNacl.dylib', '-emit-module-path', r / 'TweetNacl.swiftmodule'])
swift += ['-I', tweetmodule]
for revision in pins:
    family = r / revision[:8]
    archive(p / 'FearlessUtils', revision, family / 'source')
    source = family / 'source/FearlessUtils/Classes'
    # Exact historical method from Data+Hash.swift, without unrelated xxHash helpers.
    glue = family / 'Data+Blake.swift'
    glue.write_text('import Foundation\nimport IrohaCrypto\npublic extension Data {\n    func blake2b32() throws -> Data {\n        try (self as NSData).blake2b(32)\n    }\n}\n')
    files = [source / 'Scale/ScaleCoding.swift', source / 'Scale/Encodable/String+Scale.swift', source / 'Scale/Encodable/BigInt+Scale.swift',
             *[source / 'Common' / (name + '.swift') for name in ['Data+Hex', 'Data+Random', 'CryptoType', 'ChainType']],
             *list((source / 'Keystore').glob('*.swift')), glue,
             *[source / 'Crypto' / relative for relative in ['SeedFactory.swift', 'Data+Seed.swift', 'JunctionFactory/Chaincode.swift',
               'JunctionFactory/JunctionFactory.swift', 'JunctionFactory/SubstrateJunctionFactory.swift', 'KeypairFactory/KeypairFactory.swift',
               'KeypairFactory/SR25519KeypairFactory.swift', 'KeypairFactory/Ed25519KeypairFactory.swift', 'KeypairFactory/EcdsaKeypairFactory.swift']]]
    run([*swift, '-lBigInt', '-lIrohaCrypto', '-lTweetNacl', '-emit-library', '-emit-module', '-module-name', 'FearlessUtils', *files,
         '-o', family / 'libFearlessUtils.dylib', '-emit-module-path', family / 'FearlessUtils.swiftmodule'])
    run([*swift, '-I', family, '-L', family, '-lBigInt', '-lIrohaCrypto', '-lTweetNacl', '-lFearlessUtils',
         p / 'generate_fearless.swift', '-o', family / 'generate_fearless'])
    run([family / 'generate_fearless', p / ('ios-fearless-' + revision[:8] + '-vectors.json'), revision], discard_stdout=True)
    print('Historical FearlessUtils ' + revision[:8] + ': generated and verified')
