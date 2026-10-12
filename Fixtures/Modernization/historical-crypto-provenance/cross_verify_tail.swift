// Run each retained historical implementation against every fixed export.
precondition(CommandLine.arguments.count >= 3)
var results: [[String: Any]] = []
for inputPath in CommandLine.arguments.dropFirst(2) {
    let inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
    let root = try JSONSerialization.jsonObject(with: inputData) as! [String: Any]
    let inputs = root["vectors"] as! [[String: Any]]
    for vector in inputs {
        let type = CryptoType(rawValue: vector["cryptoType"] as! String)!
        let publicKey = try parseHex(vector["publicKeyHex"] as! String)
        let secret = try parseHex(vector["secretKeyHex"] as! String)
        let signatureBytes = try parseHex(vector["signatureHex"] as! String)
        let retainedChallenge = try parseHex(vector["challengeHex"] as! String)
        precondition(retainedChallenge == challenge)
        let originalSignature: IRSignatureProtocol
        switch type {
        case .sr25519: originalSignature = try SNSignature(rawData: signatureBytes)
        case .ed25519: originalSignature = try EDSignature(rawData: signatureBytes)
        case .ecdsa: originalSignature = try SECSignature(rawData: signatureBytes)
        }
        let originalVerified = try verify(originalSignature, publicKey, type)
        precondition(originalVerified)
        let definitionBytes = try JSONSerialization.data(withJSONObject: vector["exportedJSON"]!)
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: definitionBytes)
        let extracted = try KeystoreExtractor().extractFromDefinition(definition, password: (vector["jsonPassword"] as! String))
        precondition(extracted.secretKeyData == secret && extracted.publicKeyData == publicKey)
        let reproducedAddress = try addressFactory.address(fromAccountId: publicKey, type: 69)
        precondition(reproducedAddress == vector["address"] as! String)
        let newSignature = try sign(extracted.secretKeyData, extracted.publicKeyData, type)
        let newVerified = try verify(newSignature, publicKey, type)
        precondition(newVerified)
    }
    results.append(["source": URL(fileURLWithPath: inputPath).lastPathComponent,
                    "verifiedOriginalSignatures": inputs.count, "verifiedExportImportIdentity": inputs.count,
                    "verifiedImportedKeySignatures": inputs.count])
}
let result = try JSONSerialization.data(withJSONObject: ["checks": results], options: [.prettyPrinted, .sortedKeys])
try (result + Data("\n".utf8)).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
