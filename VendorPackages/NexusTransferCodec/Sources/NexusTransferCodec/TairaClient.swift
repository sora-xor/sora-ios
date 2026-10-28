import CryptoKit
import Foundation

/// Testnet transport policy: authenticate the canonical HTTPS node and bind all
/// signed material to its pinned genesis. Confirmations are node-reported;
/// this is deliberately not an independently verified consensus light client.
public final class TairaClient {
    public static let origin = URL(string: "https://taira.sora.org")!
    public static let networkLiteral = "hash:5C3E66C94E079079FF4FC46F59810B9C4EC7B2646DD45CE937831C0FDCE20C9B#44D9"
    public static let networkBytes = Data(hexadecimal: "5c3e66c94e079079ff4fc46f59810b9c4ec7b2646dd45ce937831c0fdce20c9b")!
    public static let xorDefinition = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"
    public enum Failure: Error { case invalidResponse, quoteExpired, rejected(Int), wrongNetwork }
    public typealias Transport = (URLRequest, Int) async throws -> Data
    private let transport: Transport

    public init(transport: Transport? = nil) {
        self.transport = transport ?? Self.send
    }

    public struct Draft {
        public let authority: String
        public let authorityHeader: String
        public let authorityKey: Data
        public let recipientKey: Data
        public let amount: String
        public let createdAt: UInt64
        public let nonce: UInt32
        public init(authority: String, authorityHeader: String, authorityKey: Data, recipientKey: Data, amount: String, createdAt: UInt64 = TairaClient.now(), nonce: UInt32 = .random(in: 1...UInt32.max)) throws {
            guard authorityKey.count == 32, recipientKey.count == 32,
                  authorityHeader.hasPrefix("0x"), authorityHeader.utf8.allSatisfy({ $0 < 128 }) else { throw Failure.invalidResponse }
            self.authority = authority; self.authorityHeader = authorityHeader
            self.authorityKey = authorityKey; self.recipientKey = recipientKey
            self.amount = try NexusTransferCodec.canonicalQuantity(amount)
            self.createdAt = createdAt; self.nonce = nonce
        }
        public func payload(fees: [NexusTransferCodec.FeeLimit]) throws -> Data {
            try NexusTransferCodec.payload(network: TairaClient.networkBytes, authorityKey: authorityKey,
                recipientKey: recipientKey, assetDefinition: TairaClient.xorDefinition, amount: amount,
                creationTimeMs: createdAt, ttlMs: 100_000, nonce: nonce, fees: fees)
        }
        public func quoteBody() throws -> Data {
            let instruction = try NexusTransferCodec.instructionJSON(authorityKey: authorityKey, recipientKey: recipientKey,
                assetDefinition: TairaClient.xorDefinition, amount: amount)
            return try JSONSerialization.data(withJSONObject: ["payload": [
                "domain": ["kind": "network", "value": TairaClient.networkLiteral],
                "authority": authority, "creation_time_ms": createdAt,
                "instructions": ["Instructions": [instruction]], "time_to_live_ms": 100_000,
                "nonce": nonce, "fee_payment": ["payer": "authority", "value": ["charge_limits": [], "gas_limit": NSNull()]],
                "metadata": [:], "attachments": NSNull()
            ]], options: [.sortedKeys])
        }
        public func requireFresh(now: UInt64 = TairaClient.now()) throws {
            guard createdAt <= now + 5_000, now < createdAt + 80_000 else { throw Failure.quoteExpired }
        }
    }

    public struct Quote {
        public let fees: [NexusTransferCodec.FeeLimit]
        public let payload: Data
        public let identity: String
        public var maxima: [String] { fees.map(\.maximum) }
    }

    public func quote(_ draft: Draft, sign: (Data) throws -> Data) async throws -> Quote {
        try draft.requireFresh()
        let body = try draft.quoteBody()
        var request = URLRequest(url: Self.origin.appendingPathComponent("v1/fees/quote"))
        request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let timestamp = Self.now(), nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let message = Self.authMessage(body: body, timestamp: timestamp, nonce: nonce)
        let signature = try sign(message)
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: draft.authorityKey),
              key.isValidSignature(signature, for: message) else { throw Failure.invalidResponse }
        request.setValue(draft.authorityHeader, forHTTPHeaderField: "X-Iroha-Account")
        request.setValue(signature.base64EncodedString(), forHTTPHeaderField: "X-Iroha-Signature")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-Iroha-Timestamp-Ms")
        request.setValue(nonce, forHTTPHeaderField: "X-Iroha-Nonce")
        let data = try await transport(request, 65_536)
        try draft.requireFresh()
        return try Self.decodeQuote(data, draft: draft)
    }

    public static func authMessage(body: Data, timestamp: UInt64, nonce: String) -> Data {
        Data("iroha.app.request.network.v1\0".utf8) + networkBytes
            + Data("POST\n/v1/fees/quote\n\n\(Data(SHA256.hash(data: body)).hexadecimal)\n\(timestamp)\n\(nonce)".utf8)
    }

    public static func decodeQuote(_ data: Data, draft: Draft) throws -> Quote {
        guard data.count <= 65_536,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == ["intent", "observation", "components", "capacities", "decision"],
              let intent = root["intent"] as? [String: Any], Set(intent.keys) == ["payer", "value"],
              intent["payer"] as? String == "authority",
              let value = intent["value"] as? [String: Any], Set(value.keys) == ["charge_limits", "gas_limit"],
              value["gas_limit"] is NSNull,
              let limits = value["charge_limits"] as? [[String: Any]], limits.count <= 2,
              let components = root["components"] as? [[String: Any]],
              NSArray(array: limits).isEqual(to: components),
              let capacities = root["capacities"] as? [Any], capacities.isEmpty,
              let observation = root["observation"] as? [String: Any],
              Set(observation.keys) == ["ledger_time_ms", "next_block_height", "route_dataspace_id"],
              integer(observation["ledger_time_ms"]) != nil,
              integer(observation["next_block_height"]).map({ $0 > 0 }) == true,
              integer(observation["route_dataspace_id"]) == 0,
              let decision = root["decision"] as? [String: Any], Set(decision.keys) == ["status", "value"],
              decision["status"] as? String == "accepted",
              let accepted = decision["value"] as? [String: Any], Set(accepted.keys) == ["debit_source", "program_revision"],
              accepted["program_revision"] is NSNull,
              let debit = accepted["debit_source"] as? [String: Any], Set(debit.keys) == ["kind", "value"],
              debit["kind"] as? String == "account", debit["value"] as? String == draft.authority
        else { throw Failure.invalidResponse }
        var fees: [NexusTransferCodec.FeeLimit] = []
        for limit in limits {
            guard Set(limit.keys) == ["kind", "asset_definition_id", "max_amount"],
                  let kind = limit["kind"] as? [String: Any], Set(kind.keys) == ["kind", "value"], kind["value"] is NSNull,
                  let name = kind["kind"] as? String, ["nexus", "pipeline_gas"].contains(name),
                  limit["asset_definition_id"] as? String == xorDefinition,
                  let maximum = limit["max_amount"] as? String,
                  try NexusTransferCodec.canonicalQuantity(maximum, allowZero: true) == maximum
            else { throw Failure.invalidResponse }
            let tag: UInt32 = name == "nexus" ? 0 : 1
            guard fees.last.map({ $0.kind < tag }) ?? true else { throw Failure.invalidResponse }
            fees.append(.init(kind: tag, assetDefinition: xorDefinition, maximum: maximum))
        }
        let payload = try draft.payload(fees: fees)
        return Quote(fees: fees, payload: payload, identity: NexusTransferCodec.signingMessage(payload).hexadecimal)
    }

    public struct Checkpoint { public let height: Int64; public let hash: String }
    public func checkpoint() async throws -> Checkpoint {
        let challenge = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        var request = URLRequest(url: Self.origin.appendingPathComponent("v1/bridge/finality/attestation/latest"))
        request.setValue(challenge, forHTTPHeaderField: "X-Iroha-Finality-Challenge")
        let data = try await transport(request, 8 * 1024 * 1024)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = root["body"] as? [String: Any],
              body["challenge"] as? String == challenge.uppercased(),
              body["network_id"] as? String == Self.networkLiteral,
              body["genesis_block_hash"] as? String == Self.networkLiteral,
              let observed = Self.integer(body["observed_at_unix_ms"]), abs(Double(observed) - Double(Self.now())) < 60_000,
              let status = body["status"] as? [String: Any],
              let height = Self.integer(status["applied_height"]), height > 0, height <= UInt64(Int64.max),
              Self.integer(status["committed_height"]).map({ $0 >= height }) == true
        else { throw Failure.wrongNetwork }
        let blockData = try await transport(URLRequest(url: Self.origin.appendingPathComponent("v1/explorer/blocks/\(height)")), 65_536)
        guard let block = try JSONSerialization.jsonObject(with: blockData) as? [String: Any],
              Self.integer(block["height"]) == height,
              let literal = block["hash"] as? String,
              let hash = Self.hashLiteral(literal)
        else { throw Failure.invalidResponse }
        return Checkpoint(height: Int64(height), hash: hash)
    }

    public static func now() -> UInt64 { UInt64(Date().timeIntervalSince1970 * 1_000) }
    static func integer(_ value: Any?) -> UInt64? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.stringValue.range(of: "^(0|[1-9][0-9]*)$", options: .regularExpression) != nil else { return nil }
        return UInt64(n.stringValue)
    }
    public static func hashLiteral(_ literal: String) -> String? {
        guard literal.range(of: "^hash:[0-9A-F]{64}#[0-9A-F]{4}$", options: .regularExpression) != nil else { return nil }
        var crc: UInt16 = 0xffff
        for byte in literal.prefix(69).utf8 {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 { crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1 }
        }
        guard UInt16(literal.suffix(4), radix: 16) == crc else { return nil }
        // Checking the hash literal is not independent consensus verification.
        let hex = String(literal.dropFirst(5).prefix(64)).lowercased()
        guard let bytes = Data(hexadecimal: hex), bytes.last! & 1 == 1 else { return nil }
        return hex
    }
    private static func send(_ input: URLRequest, maximum: Int) async throws -> Data {
        guard input.url?.scheme == "https", input.url?.host == "taira.sora.org", input.url?.port == nil,
              input.url?.user == nil, input.url?.password == nil else { throw Failure.wrongNetwork }
        var request = input; request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCache = nil
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.url == request.url else { throw Failure.invalidResponse }
        guard http.statusCode == 200 else { throw Failure.rejected(http.statusCode) }
        guard http.mimeType == "application/json", response.expectedContentLength <= Int64(maximum) else { throw Failure.invalidResponse }
        var data = Data()
        for try await byte in stream {
            guard data.count < maximum else { throw Failure.invalidResponse }
            data.append(byte)
        }
        return data
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

extension Data {
    init?(hexadecimal: String) {
        guard hexadecimal.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hexadecimal.startIndex
        while index < hexadecimal.endIndex {
            let next = hexadecimal.index(index, offsetBy: 2)
            guard let byte = UInt8(hexadecimal[index..<next], radix: 16) else { return nil }
            bytes.append(byte); index = next
        }
        self.init(bytes)
    }
    var hexadecimal: String { map { String(format: "%02x", $0) }.joined() }
}
