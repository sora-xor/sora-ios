// Synthetic/public inputs only. All crypto/derivation/export APIs below are
// linked from retained historical dependencies, never the audit's patched code.
import Foundation
import IrohaCrypto
import SSFModels
import SSFUtils
import SSFCrypto

let challenge = Data("SORA historical fixture audit 2026-10-12".utf8)
let password = "public-json-fixture-password"
let addressFactory = SS58AddressFactory()
let phraseFactory = IRMnemonicCreator(language: .english)
var vectors: [[String: Any]] = []

func keyFactory(_ type: CryptoType) -> KeypairFactoryProtocol {
    switch type {
    case .sr25519: return SR25519KeypairFactory()
    case .ed25519: return Ed25519KeypairFactory()
    case .ecdsa: return EcdsaKeypairFactory()
    }
}

// These calls follow App Store 354f176c SigningWrapperProtocol exactly. The
// factory/primitive code itself is the original compiled dependency source.
func sign(_ secret: Data, _ publicKey: Data, _ type: CryptoType) throws -> IRSignatureProtocol {
    switch type {
    case .sr25519:
        return try SNSigner(keypair: SNKeypair(privateKey: SNPrivateKey(rawData: secret),
                                              publicKey: SNPublicKey(rawData: publicKey))).sign(challenge)
    case .ed25519:
        let privateKey = try Ed25519KeypairFactory().createKeypairFromSeed(secret.miniSeed, chaincodeList: []).privateKey()
        return try EDSigner(privateKey: privateKey).sign(challenge)
    case .ecdsa:
        let privateKey = try EcdsaKeypairFactory().createKeypairFromSeed(secret.miniSeed, chaincodeList: []).privateKey()
        return try SECSigner(privateKey: privateKey).sign(challenge.blake2b32())
    }
}

func verify(_ signature: IRSignatureProtocol, _ publicKey: Data, _ type: CryptoType) throws -> Bool {
    switch type {
    case .sr25519:
        return try SNSignatureVerifier().verify(SNSignature(rawData: signature.rawData()), forOriginalData: challenge,
                                                using: SNPublicKey(rawData: publicKey))
    case .ed25519:
        return try EDSignatureVerifier().verify(signature, forOriginalData: challenge, usingPublicKey: EDPublicKey(rawData: publicKey))
    case .ecdsa:
        return try SECSignatureVerifier().verify(signature, forOriginalData: challenge.blake2b32(), usingPublicKey: SECPublicKey(rawData: publicKey))
    }
}

let cases: [(Int, CryptoType, String, String)] = [3, 6, 9, 12].flatMap { count in
    CryptoType.allCases.map { (count, $0, "", "") }
} + [(12, .sr25519, "/soft", ""), (12, .sr25519, "//hard", ""),
     (12, .sr25519, "//hard/soft///public-path-password", ""),
     (12, .ed25519, "//hard///public-path-password", ""),
     (12, .ecdsa, "//hard///public-path-password", ""),
     (12, .ed25519, "//hard", "json64"),
     (12, .ed25519, "//hard", "json64-stale-redundant-half"),
     (15, .sr25519, "", "legacy-phrase-migration")]

for (wordCount, type, path, shape) in cases {
    let entropy = Data(repeating: 0, count: wordCount / 3 * 4)
    // Historical entropy->words rejects less than 128 bits, while its typed
    // words->entropy path accepts these checksum-valid 3/6/9-word inputs.
    let shortPhrases = [3: "abandon abandon ability", 6: "abandon abandon abandon abandon abandon able",
                        9: "abandon abandon abandon abandon abandon abandon abandon abandon abandon"]
    let mnemonic = try shortPhrases[wordCount].map { try phraseFactory.mnemonic(fromList: $0) }
        ?? phraseFactory.mnemonic(fromEntropy: entropy)
    precondition(mnemonic.entropy() == entropy)
    let phrase = mnemonic.toString()
    precondition(mnemonic.numberOfWords() == wordCount)
    let junctions = path.isEmpty ? nil : try SubstrateJunctionFactory().parse(path: path)
    let seed = try SeedFactory().deriveSeed(from: phrase, password: junctions?.password ?? "").seed.miniSeed
    let chaincodes = junctions?.chaincodes ?? []
    let pair = try keyFactory(type).createKeypairFromSeed(seed, chaincodeList: chaincodes)
    let publicKey = pair.publicKey().rawData()
    let address = try addressFactory.address(fromAccountId: publicKey, type: 69)
    var secret: Data
    switch type {
    case .sr25519: secret = pair.privateKey().rawData()
    case .ed25519: secret = try Ed25519KeypairFactory().deriveChildSeedFromParent(seed, chaincodeList: chaincodes)
    case .ecdsa: secret = try EcdsaKeypairFactory().deriveChildSeedFromParent(seed, chaincodeList: chaincodes)
    }
    let childSeed = type == .sr25519 ? nil : secret
    if shape == "json64" { secret += publicKey }
    if shape == "json64-stale-redundant-half" { secret += Data(repeating: 0xa5, count: 32) }
    let signature = try sign(secret, publicKey, type)
    let verified = try verify(signature, publicKey, type)
    precondition(verified, "Historical signature did not verify")
    let id = "ios-386-\(type.stringValue)-\(wordCount)words-\(vectors.count)"
    let definition = try KeystoreBuilder().with(name: id).with(creationDate: Date(timeIntervalSince1970: 0))
        .build(from: KeystoreData(address: address, secretKeyData: secret, publicKeyData: publicKey, cryptoType: type),
               password: password, isEthereum: false)
    let imported = try KeystoreExtractor().extractFromDefinition(definition, password: password)
    precondition(imported.secretKeyData == secret && imported.publicKeyData == publicKey)
    let importedSignature = try sign(imported.secretKeyData, imported.publicKeyData, type)
    let importedVerified = try verify(importedSignature, imported.publicKeyData, type)
    precondition(importedVerified)
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(definition))
    var vector: [String: Any] = [
        "id": id, "family": "shared-features-spm-ada44b24", "cryptoType": type.stringValue,
        "wordCount": wordCount, "entropyHex": entropy.toHex(), "phrase": phrase, "derivationPath": path,
        "seedHex": seed.toHex(), "secretKeyHex": secret.toHex(), "publicKeyHex": publicKey.toHex(),
        "networkType": 69, "address": address, "challengeHex": challenge.toHex(),
        "signatureHex": signature.rawData().toHex(), "signatureVerified": verified,
        "jsonPassword": password, "exportedJSON": json, "exportRoundTripVerified": true,
        "secretShape": shape.isEmpty ? "direct" : shape,
        "chaincodes": chaincodes.map { ["type": $0.type == .hard ? "hard" : "soft", "dataHex": $0.data.toHex()] }
    ]
    if let childSeed = childSeed {
        vector["childSeedHex"] = childSeed.toHex()
        let reimport = try keyFactory(type).createKeypairFromSeed(childSeed, chaincodeList: [])
        precondition(reimport.publicKey().rawData() == publicKey)
        vector["childSeedImportSameIdentity"] = true
    }
    vectors.append(vector)
}
let output = try JSONSerialization.data(withJSONObject: ["vectors": vectors], options: [.prettyPrinted, .sortedKeys])
// The historical scrypt C source has a stray binary printf. Keep it unchanged
// for provenance and write fixture JSON through a separate file descriptor.
precondition(CommandLine.arguments.count == 2)
try (output + Data("\n".utf8)).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
