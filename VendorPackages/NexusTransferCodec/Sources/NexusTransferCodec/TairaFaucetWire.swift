import CryptoKit
import Foundation

extension TairaFaucetClient {
    /// The prepared JSON is retained unchanged for submission, but trust is in
    /// the checked signed wire, not the server's descriptive JSON fields.
    static func validatePrepared(_ data: Data, account: String, publicKey: Data,
                                 claim: [String: Any], binding: [String: Any], semantic: String,
                                 now: UInt64) throws -> String {
        let root = try object(data)
        guard root["schema"] as? String == "iroha.prepared-transaction.v1",
              root["operation"] as? String == "faucet",
              equalJSON(root["binding"], binding), equalJSON(root["claim"], claim),
              root["semantic_hash_hex"] as? String == semantic,
              root["account_id"] as? String == account,
              root["asset_definition_id"] as? String == TairaClient.xorDefinition,
              root["asset_id"] as? String == "\(TairaClient.xorDefinition)#\(account)",
              root["amount"] as? String == amount,
              let hash = root["transaction_hash_hex"] as? String, validHash(hash),
              let hex = root["signed_transaction_wire_hex"] as? String, hex.count <= 131_072,
              let wire = Data(hexadecimal: hex),
              root["signed_transaction_wire_sha256"] as? String == Data(SHA256.hash(data: wire)).hexadecimal,
              let expires = TairaClient.integer(binding["execution_expires_at_unix_ms"]), now < expires else { throw Failure.invalidResponse }
        let (payload, signature) = try signedPayload(wire)
        guard NexusTransferCodec.transactionHash(payload).hexadecimal == hash,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: authorityKey),
              key.isValidSignature(signature, for: NexusTransferCodec.signingMessage(payload)) else { throw Failure.invalidResponse }
        let f = NexusTransferCodec.field
        var fields = FaucetReader(payload)
        guard try fields.field() == NexusTransferCodec.u32(0) + f(TairaClient.networkBytes) else { throw Failure.wrongNetwork }
        guard try fields.field() == NexusTransferCodec.account(authorityKey) else { throw Failure.invalidResponse }
        var creation = FaucetReader(try fields.field())
        let createdAt = try creation.u64(); try creation.end()
        guard createdAt <= now + 5_000, createdAt < expires, expires - createdAt <= 100_000 else { throw Failure.expired }
        let instructions = try fields.field()
        var ttl = FaucetReader(try fields.field())
        guard try ttl.byte() == 1 else { throw Failure.invalidResponse }
        var ttlValue = FaucetReader(try ttl.field())
        guard try ttlValue.u64() == expires - createdAt else { throw Failure.invalidResponse }
        try ttl.end(); try ttlValue.end()
        guard try fields.field() == Data([0]) else { throw Failure.invalidResponse }
        guard let feeJSON = root["fee_payment"] as? [String: Any], try fields.field() == feeWire(feeJSON) else { throw Failure.invalidResponse }
        let metadata = try metadataJSON(fields.field())
        guard Set(metadata.keys) == ["prepared_operation", "prepared_operation_binding", "prepared_semantic_hash", "taira_faucet_claim_marker_version"],
              metadata["prepared_operation"] as? String == "faucet",
              equalJSON(metadata["prepared_operation_binding"], binding),
              metadata["prepared_semantic_hash"] as? String == semantic,
              TairaClient.integer(metadata["taira_faucet_claim_marker_version"]) == 1,
              try fields.field() == Data([0]) else { throw Failure.invalidResponse }
        try fields.end()
        try validateInstructions(instructions, recipient: publicKey)
        return hash
    }

    static func signedPayload(_ wire: Data) throws -> (Data, Data) {
        var reader = FaucetReader(wire)
        guard try reader.byte() == 1 else { throw Failure.invalidResponse }
        var wrapper = FaucetReader(try reader.field())
        var signature = FaucetReader(try wrapper.field()); try wrapper.end()
        guard try signature.u64() == 64 else { throw Failure.invalidResponse }
        var bytes = Data()
        for _ in 0..<64 { guard try signature.byte() == 1 else { throw Failure.invalidResponse }; bytes.append(try signature.byte()) }
        try signature.end()
        let payload = try reader.field()
        guard try reader.field() == Data([0]) else { throw Failure.invalidResponse }
        try reader.end(); return (payload, bytes)
    }

    private static func validateInstructions(_ data: Data, recipient: Data) throws {
        var executable = FaucetReader(data)
        guard try executable.bytes(4) == NexusTransferCodec.u32(0) else { throw Failure.invalidResponse }
        var list = FaucetReader(try executable.field()); try executable.end()
        let count = try list.u64()
        guard count == 1 || count == 2 else { throw Failure.invalidResponse }
        if count == 2 {
            let registration = try instruction(list.field())
            let f = NexusTransferCodec.field
            let account = f(try NexusTransferCodec.account(recipient)) + f(NexusTransferCodec.u64(0)) + f(Data([0])) + f(Data([0])) + f(NexusTransferCodec.u64(0))
            let body = NexusTransferCodec.u32(2) + f(f(account))
            let expected = NexusTransferCodec.frame(body, schema: Data(hexadecimal: "2e9fa44b44ac5295a0b34e05edcb4133")!)
            guard registration.0 == "iroha.register", registration.1 == expected else { throw Failure.invalidResponse }
        }
        let transfer = try instruction(list.field())
        let expected = try NexusTransferCodec.transferFrame(authorityKey: authorityKey, recipientKey: recipient,
            assetDefinition: TairaClient.xorDefinition, amount: amount)
        guard transfer.0 == "iroha.transfer", transfer.1 == expected else { throw Failure.invalidResponse }
        try list.end()
    }
    private static func instruction(_ data: Data) throws -> (String, Data) {
        var item = FaucetReader(data)
        var name = FaucetReader(try item.field())
        guard let string = String(data: try name.field(), encoding: .utf8) else { throw Failure.invalidResponse }
        try name.end()
        var frame = FaucetReader(try item.field()); try item.end()
        let length = try frame.u64()
        guard length <= 65_536 else { throw Failure.invalidResponse }
        let bytes = try frame.bytes(Int(length)); try frame.end()
        return (string, bytes)
    }
    static func feeWire(_ value: [String: Any]) throws -> Data {
        guard Set(value.keys) == ["payer", "value"], value["payer"] as? String == "authority",
              let intent = value["value"] as? [String: Any], Set(intent.keys) == ["charge_limits", "gas_limit"],
              intent["gas_limit"] is NSNull, let limits = intent["charge_limits"] as? [[String: Any]], limits.count <= 2 else { throw Failure.invalidResponse }
        let f = NexusTransferCodec.field
        var bytes = NexusTransferCodec.u64(UInt64(limits.count)), previous: UInt32?
        for limit in limits {
            guard Set(limit.keys) == ["kind", "asset_definition_id", "max_amount"],
                  let kind = limit["kind"] as? [String: Any], Set(kind.keys) == ["kind", "value"], kind["value"] is NSNull,
                  let label = kind["kind"] as? String, ["nexus", "pipeline_gas"].contains(label),
                  limit["asset_definition_id"] as? String == TairaClient.xorDefinition,
                  let maximum = limit["max_amount"] as? String,
                  try NexusTransferCodec.canonicalQuantity(maximum, allowZero: true) == maximum else { throw Failure.invalidResponse }
            let tag: UInt32 = label == "nexus" ? 0 : 1
            guard previous == nil || previous! < tag else { throw Failure.invalidResponse }; previous = tag
            bytes += f(f(NexusTransferCodec.u32(tag)) + f(try NexusTransferCodec.asset(TairaClient.xorDefinition)) + f(try NexusTransferCodec.quantity(maximum, allowZero: true)))
        }
        return NexusTransferCodec.u32(0) + f(f(bytes) + f(Data([0])))
    }
    private static func metadataJSON(_ data: Data) throws -> [String: Any] {
        var reader = FaucetReader(data)
        guard try reader.u64() == 4 else { throw Failure.invalidResponse }
        var result: [String: Any] = [:]
        for _ in 0..<4 {
            var entry = FaucetReader(try reader.field())
            var key = FaucetReader(try entry.field())
            guard let name = String(data: try key.field(), encoding: .utf8), result[name] == nil else { throw Failure.invalidResponse }
            try key.end()
            var wrapper = FaucetReader(try entry.field()); try entry.end()
            var value = FaucetReader(try wrapper.field()); try wrapper.end()
            result[name] = try JSONSerialization.jsonObject(with: value.field(), options: [.fragmentsAllowed]); try value.end()
        }
        try reader.end(); return result
    }
}

private struct FaucetReader {
    private let data: Data
    private var offset = 0
    init(_ data: Data) { self.data = data }
    mutating func byte() throws -> UInt8 {
        guard offset < data.count else { throw TairaFaucetClient.Failure.invalidResponse }
        defer { offset += 1 }; return data[data.startIndex + offset]
    }
    mutating func bytes(_ count: Int) throws -> Data {
        guard count >= 0, count <= data.count - offset else { throw TairaFaucetClient.Failure.invalidResponse }
        defer { offset += count }; return Data(data[(data.startIndex + offset)..<(data.startIndex + offset + count)])
    }
    mutating func u64() throws -> UInt64 { try bytes(8).enumerated().reduce(0) { $0 | (UInt64($1.element) << ($1.offset * 8)) } }
    mutating func field() throws -> Data {
        var length = 0, shift = 0
        while true {
            let value = try byte()
            guard shift <= 21 else { throw TairaFaucetClient.Failure.invalidResponse }
            length |= Int(value & 127) << shift
            if value & 128 == 0 {
                guard shift == 0 || value != 0 else { throw TairaFaucetClient.Failure.invalidResponse }
                return try bytes(length)
            }
            shift += 7
        }
    }
    func end() throws { guard offset == data.count else { throw TairaFaucetClient.Failure.invalidResponse } }
}
