#!/usr/bin/env python3
"""Execute exact active pre-SPM SSFUtils and SSFModels app pins.
Run build_fearless.py first to create the shared original IrohaCrypto 0.9 pods.
"""
import io
import json
from pathlib import Path
import subprocess
import tarfile

p = Path(__file__).resolve().parent
r = p / 'runtime/fearless-build'
commands = []

def run(command, discard_stdout=False):
    command = list(map(str, command)); commands.append(command)
    result = subprocess.run(command, stdout=subprocess.DEVNULL if discard_stdout else subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, errors='replace')
    with (p / 'build-ssf-pod.log').open('a') as log:
        log.write((result.stdout or '') + result.stderr)
    (p / 'build-ssf-pod-commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    if result.returncode:
        print(result.stderr[-9000:]); raise SystemExit(result.returncode)

def archive(revision, destination):
    destination.mkdir(parents=True, exist_ok=True)
    data = subprocess.check_output(['git', '-C', str(p / 'shared-features-ios-0.1.31'), 'archive', revision])
    with tarfile.open(fileobj=io.BytesIO(data)) as contents: contents.extractall(destination)

old = r / 'IrohaCrypto-0.9.0'
classes = old / 'IrohaCrypto/Classes'
headerdirs = sorted({header.parent for root in [classes, old / 'sr25519Imp', old / 'ed25519Imp', old / 'blake2Imp'] for header in root.rglob('*.h')})
headerargs = ['-I' + str(folder) for folder in headerdirs] + ['-I' + str(r / 'pod-headers'), '-I' + str(r / 'scrypt.c-0.1.1/scrypt/include')]
swift = ['xcrun', 'swiftc', '-swift-version', '5', '-target', 'arm64-apple-macosx13.0', '-I', r, '-I', r / 'IrohaCrypto',
         '-L', r, '-Xlinker', '-rpath', '-Xlinker', r, '-I', r / 'CTweetNacl']
for include in headerargs: swift += ['-Xcc', include]
utilsRevision = '2b1d7ca85acfdf48e2d1c69f9e9e473f137868eb'
for modelsVersion, modelsRevision in [('0.1.31', utilsRevision), ('0.1.32', 'e266039f6c5640ba3140472b0c983d88ffd2f6d6')]:
    family = r / ('ssfutils-0.1.31-models-' + modelsVersion)
    archive(utilsRevision, family / 'utils-source')
    archive(modelsRevision, family / 'models-source')
    source = family / 'utils-source/SSFUtils/SSFUtils/Classes'
    modelsSource = family / 'models-source/SSFModels/SSFModels/Classes'
    modelsGlue = family / 'ModelsImports.swift'
    modelsGlue.write_text('import IrohaCrypto\n')
    run([*swift, '-lIrohaCrypto', '-emit-library', '-emit-module', '-module-name', 'SSFModels',
         modelsSource / 'Data+Hex.swift', modelsGlue, '-o', family / 'libSSFModels.dylib',
         '-emit-module-path', family / 'SSFModels.swiftmodule'])
    # Exact historical method; imports replace unrelated full-module dependencies.
    glue = family / 'Data+Blake.swift'
    glue.write_text('import Foundation\nimport IrohaCrypto\nimport SSFModels\npublic extension Data {\n    func blake2b32() throws -> Data {\n        try (self as NSData).blake2b(32)\n    }\n}\n')
    files = [source / 'Scale/ScaleCoding.swift', source / 'Scale/Encodable/String+Scale.swift', source / 'Scale/Encodable/BigInt+Scale.swift',
             *[source / 'Common' / (name + '.swift') for name in ['Data+Random', 'CryptoType', 'ChainType']],
             *list((source / 'Keystore').glob('*.swift')), glue,
             *[source / 'Crypto' / relative for relative in ['SeedFactory.swift', 'Data+Seed.swift', 'JunctionFactory/Chaincode.swift',
               'JunctionFactory/JunctionFactory.swift', 'JunctionFactory/SubstrateJunctionFactory.swift', 'KeypairFactory/KeypairFactory.swift',
               'KeypairFactory/SR25519KeypairFactory.swift', 'KeypairFactory/Ed25519KeypairFactory.swift', 'KeypairFactory/EcdsaKeypairFactory.swift']]]
    familySwift = [*swift, '-I', family, '-L', family]
    run([*familySwift, '-lBigInt', '-lIrohaCrypto', '-lTweetNacl', '-lSSFModels', '-emit-library', '-emit-module', '-module-name', 'SSFUtils', *files,
         '-o', family / 'libSSFUtils.dylib', '-emit-module-path', family / 'SSFUtils.swiftmodule'])
    run([*familySwift, '-lBigInt', '-lIrohaCrypto', '-lTweetNacl', '-lSSFModels', '-lSSFUtils',
         p / 'generate_ssf_pod.swift', '-o', family / 'generate_ssf_pod'])
    run([family / 'generate_ssf_pod', p / ('ios-ssfutils-0.1.31-models-' + modelsVersion + '-vectors.json'), modelsVersion], discard_stdout=True)
    print('Historical SSFUtils 0.1.31 / SSFModels ' + modelsVersion + ': generated and verified')
