import CryptoKit
import Foundation

/// Public testnet funding. No user signing key is read or sent. The canonical
/// HTTPS node supplies a faucet-signed transaction; its exact instructions,
/// network, claim binding and signature are checked before a one-shot submit.
public actor TairaFaucetClient {
    public static let amount = "25000"
    public static let authority = "testuﾛ1PpﾜｲﾇLikｦdMxLﾖ8QﾜXRbﾈTｴｷｵg9juｲCｴS9Cyﾎ3ﾐUXHFVF"
    static let authorityKey = Data(hexadecimal: "9df446200b9ddc5c76d17935ec2f4a4e3efd56cbcaba436289abdd1e398e6021")!
    public typealias Scrypt = @Sendable (Data, Data, UInt64, UInt32, UInt32) throws -> Data
    public typealias Transport = @Sendable (URLRequest, Int) async throws -> Response
    public struct Response: Sendable {
        public let data: Data
        public let statusCode: Int
        public let retryAfterSeconds: TimeInterval?
        public init(data: Data, statusCode: Int = 200, retryAfterSeconds: TimeInterval? = nil) {
            self.data = data; self.statusCode = statusCode; self.retryAfterSeconds = retryAfterSeconds
        }
    }
    public enum Failure: Error, Equatable {
        case invalidResponse, wrongNetwork, resourceLimit, expired, alreadySubmitted
        case rateLimited(retryAfterSeconds: TimeInterval?)
        case rejectedHTTP(Int)
    }
    public struct PreparedClaim: Sendable {
        public let account: String
        public let amount: String
        public let transactionHash: String
        public let expiresAt: UInt64
        fileprivate let body: Data
        fileprivate let clientID: UUID
    }
    public struct Outcome: Sendable {
        public enum State: Sendable, Equatable {
            case applied(blockHeight: UInt64), pending, rejected(reason: String)
        }
        public let amount: String
        public let transactionHash: String
        public let state: State
    }
    /// How often a solve stops to read the puzzle again. Not a limit on how long it may take.
    struct SolvePacing: Sendable {
        var puzzleRefresh: TimeInterval = 15
        var uptime: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    }
    private let scrypt: Scrypt
    private let transport: Transport
    private let clock: @Sendable () -> UInt64
    private let clientID = UUID()
    private let requestIDGenerator: @Sendable () -> String
    private let pacing: SolvePacing
    private var attempted: Set<String> = []

    public init(scrypt: @escaping Scrypt, transport: Transport? = nil,
                clock: @escaping @Sendable () -> UInt64 = { TairaClient.now() }) {
        self.scrypt = scrypt; self.transport = transport ?? { request, maximum in try await Self.send(request, maximum: maximum) }; self.clock = clock
        self.requestIDGenerator = { Self.requestID() }; self.pacing = SolvePacing()
    }

    init(scrypt: @escaping Scrypt, transport: @escaping Transport,
         clock: @escaping @Sendable () -> UInt64, requestID: @escaping @Sendable () -> String,
         pacing: SolvePacing = SolvePacing()) {
        self.scrypt = scrypt; self.transport = transport; self.clock = clock; self.requestIDGenerator = requestID; self.pacing = pacing
    }

    /// What the screen says when a claim ends in `error`, as a key of the app's
    /// Localizable.strings. Only a failed request blames the connection.
    public static func failureMessage(for error: Error) -> String {
        switch error {
        case Failure.resourceLimit: return "Your test XOR could not be prepared on this device. Please try again later."
        case is URLError: return "Could not get test XOR. Check your connection and try again."
        default: return "The faucet request was not completed. Please try again."
        }
    }

    /// Caller must decode the canonical Taira address and supply its matching
    /// Ed25519 key. App context may be checked again between prepare and submit.
    public func prepare(account: String, publicKey: Data) async throws -> PreparedClaim {
        try Task.checkCancellation()
        guard account.hasPrefix("test"), account.utf8.count <= 256,
              !account.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              publicKey.count == 32, publicKey.contains(where: { $0 != 0 }) else { throw Failure.invalidResponse }
        let policy = try await get("v1/accounts/faucet/policy")
        guard TairaClient.integer(policy["schema_version"]) == 1,
              policy["network_id"] as? String == TairaClient.networkLiteral,
              TairaClient.integer(policy["network_prefix"]) == 369 else { throw Failure.wrongNetwork }
        guard policy["authority"] as? String == Self.authority,
              policy["asset_definition_id"] as? String == TairaClient.xorDefinition,
              policy["amount"] as? String == Self.amount else { throw Failure.invalidResponse }
        var proof = try Self.puzzle(try await get("v1/accounts/faucet/puzzle"), account: account)
        var nextNonce: UInt64 = 0, refused = 0
        while true {
            let nonce: Data
            (proof, nonce) = try await solveOnNewestAnchor(proof, account: account, nextNonce: &nextNonce)
            try Task.checkCancellation()
            let claim: [String: Any] = ["account_id": account, "pow_anchor_height": proof.height, "pow_nonce_hex": nonce.hexadecimal]
            let semantic = Self.semanticHash(account: account, height: proof.height, nonce: nonce.hexadecimal)
            let now = clock()
            guard now <= UInt64.max - 100_000 else { throw Failure.invalidResponse }
            let expires = now + 100_000
            let binding: [String: Any] = ["schema": "iroha.prepared-operation.binding.v1", "semantic_hash_hex": semantic,
                "kind": "faucet", "request_id": requestIDGenerator(), "execution_expires_at_unix_ms": expires]
            let body = try Self.json(["schema": "iroha.accounts.faucet.prepare.v1", "binding": binding, "claim": claim,
                "fee_payment": ["payer": "authority", "value": ["charge_limits": [], "gas_limit": NSNull()]]])
            let response = try await transport(Self.request("v1/accounts/faucet/prepare", body: body), 262_144)
            if refused < Self.maximumRefusedProofs, Self.chainMovedPastProof(response) {
                refused += 1
                try Task.checkCancellation()
                proof = try Self.puzzle(try await get("v1/accounts/faucet/puzzle"), account: account)
                continue
            }
            try Self.requireSuccess(response)
            try Task.checkCancellation()
            let hash = try Self.validatePrepared(response.data, account: account, publicKey: publicKey,
                claim: claim, binding: binding, semantic: semantic, now: clock())
            return PreparedClaim(account: account, amount: Self.amount, transactionHash: hash,
                expiresAt: expires, body: response.data, clientID: clientID)
        }
    }

    /// The node refuses an anchor older than `max_anchor_age_blocks` (6, which a busy
    /// chain passes in under a minute), so a slow solve must not outlive its anchor.
    /// It keeps moving to the newest puzzle, which loses nothing: every try is
    /// independent of the tries before it.
    private func solveOnNewestAnchor(_ start: Puzzle, account: String, nextNonce: inout UInt64) async throws -> (Puzzle, Data) {
        var proof = start
        while true {
            try Task.checkCancellation()
            let current = proof, first = nextNonce
            let worker = Task.detached(priority: .userInitiated) { [scrypt, pacing] in
                try Self.solve(current, from: first, until: pacing.uptime() + pacing.puzzleRefresh, uptime: pacing.uptime, scrypt: scrypt)
            }
            let stretch = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            nextNonce = stretch.next
            if let nonce = stretch.solution { return (current, nonce) }
            // A failed read costs nothing here: the tries so far still count,
            // and the prepare request reports a problem that lasts.
            if let fresher = try? Self.puzzle(try await get("v1/accounts/faucet/puzzle"), account: account), fresher.height >= proof.height {
                proof = fresher
            }
        }
    }

    /// Dispatches exactly once. Persist transactionHash before calling. Network
    /// interruption is ambiguous: retain the hash and call resume, never re-claim.
    public func submit(_ claim: PreparedClaim) async throws -> Outcome {
        try Task.checkCancellation()
        guard claim.clientID == clientID else { throw Failure.invalidResponse }
        guard !attempted.contains(claim.transactionHash) else { throw Failure.alreadySubmitted }
        guard clock() < claim.expiresAt else { throw Failure.expired }
        attempted.insert(claim.transactionHash)
        let pending = Outcome(amount: claim.amount, transactionHash: claim.transactionHash, state: .pending)
        do {
            let response = try await transport(Self.request("v1/accounts/faucet", body: claim.body), 65_536)
            try Self.requireSuccess(response)
            let object = try Self.object(response.data)
            guard object["schema"] as? String == "iroha.prepared-transaction-submit.v1",
                  object["operation"] as? String == "faucet",
                  object["transaction_hash_hex"] as? String == claim.transactionHash,
                  Self.equalJSON(object["binding"], try Self.object(claim.body)["binding"]) else { return pending }
            // A submit receipt is never proof of Applied; always reconcile status.
            return pending
        } catch let failure as Failure {
            if case .rateLimited = failure { throw failure }
            return pending
        } catch { return pending }
    }

    /// Read-only recovery, including after app restart. 404, local timeout and
    /// transport failures remain pending; only global state-resolved Applied is success.
    public func resume(transactionHash: String, amount: String = TairaFaucetClient.amount,
                       timeout: TimeInterval = 45) async throws -> Outcome {
        guard Self.validHash(transactionHash), amount == Self.amount,
              timeout.isFinite, (0...120).contains(timeout) else { throw Failure.invalidResponse }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let pending = Outcome(amount: amount, transactionHash: transactionHash, state: .pending)
        repeat {
            try Task.checkCancellation()
            var components = URLComponents(url: TairaClient.origin.appendingPathComponent("v1/pipeline/transactions/status"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "hash", value: transactionHash)]
            do {
                let response = try await transport(URLRequest(url: components.url!), 65_536)
                if response.statusCode != 404 {
                    try Self.requireSuccess(response)
                    let root = try Self.object(response.data)
                    guard root["hash"] as? String == transactionHash,
                          root["scope"] as? String == "global",
                          let status = root["status"] as? [String: Any],
                          let kind = status["kind"] as? String else { throw Failure.invalidResponse }
                    if kind == "Applied" {
                        guard root["resolved_from"] as? String == "state",
                              let height = TairaClient.integer(status["block_height"]), height > 0 else { throw Failure.invalidResponse }
                        return Outcome(amount: amount, transactionHash: transactionHash, state: .applied(blockHeight: height))
                    }
                    if kind == "Rejected" {
                        guard root["resolved_from"] as? String == "state" else { throw Failure.invalidResponse }
                        return Outcome(amount: amount, transactionHash: transactionHash,
                            state: .rejected(reason: "The Taira network rejected this faucet request."))
                    }
                }
            } catch is CancellationError { throw CancellationError() }
            catch let failure as Failure {
                if case .rateLimited = failure { throw failure }
                if failure == .invalidResponse || failure == .wrongNetwork { throw failure }
            } catch { /* Preserve ambiguous requests for later read-only recovery. */ }
            if ProcessInfo.processInfo.systemUptime >= deadline { return pending }
            try await Task.sleep(nanoseconds: UInt64(min(2, max(0, deadline - ProcessInfo.processInfo.systemUptime)) * 1_000_000_000))
        } while ProcessInfo.processInfo.systemUptime < deadline
        return pending
    }

    private func get(_ path: String) async throws -> [String: Any] {
        let response = try await transport(Self.request(path), 65_536)
        try Self.requireSuccess(response)
        return try Self.object(response.data)
    }
    private static func request(_ path: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: TairaClient.origin.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }
    private static func requireSuccess(_ response: Response) throws {
        if response.statusCode == 429 { throw Failure.rateLimited(retryAfterSeconds: response.retryAfterSeconds) }
        guard [200, 202].contains(response.statusCode) else { throw Failure.rejectedHTTP(response.statusCode) }
    }
    /// Solving again after this many refusals would keep a claim going without end on a node that refuses every proof.
    static let maximumRefusedProofs = 3
    /// The proof was right for the puzzle it answered, but the chain has moved on: a new puzzle can succeed.
    private static func chainMovedPastProof(_ response: Response) -> Bool {
        guard response.statusCode == 400, let code = (try? object(response.data))?["code"] as? String else { return false }
        return ["faucet_pow_anchor_stale", "faucet_pow_anchor_unknown", "faucet_pow_anchor_out_of_range",
                "faucet_pow_solution_invalid"].contains(code)
    }
    static func object(_ data: Data) throws -> [String: Any] {
        guard data.count <= 262_144, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalidResponse }
        return result
    }
    static func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]) }
    static func equalJSON(_ first: Any?, _ second: Any?) -> Bool {
        guard let first, let second else { return false }
        return (try? json(first)) == (try? json(second))
    }
    private static func requestID() -> String { (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased() }
    static func validHash(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil && Data(hexadecimal: value)!.last! & 1 == 1
    }

    struct Puzzle: Sendable {
        let height: UInt64; let difficulty: UInt64; let n: UInt64; let r: UInt32; let p: UInt32; let challenge: Data
    }
    static func puzzle(_ value: [String: Any], account: String) throws -> Puzzle {
        guard value["network_id"] as? String == TairaClient.networkLiteral,
              TairaClient.integer(value["chain_discriminant"]) == 369 else { throw Failure.wrongNetwork }
        guard value["algorithm"] as? String == "scrypt-leading-zero-bits-v1",
              let height = TairaClient.integer(value["anchor_height"]), height > 0,
              let hash = value["anchor_block_hash_hex"] as? String, validHash(hash),
              let difficulty = TairaClient.integer(value["difficulty_bits"]),
              let logN = TairaClient.integer(value["scrypt_log_n"]),
              let r = TairaClient.integer(value["scrypt_r"]), let p = TairaClient.integer(value["scrypt_p"]),
              let age = TairaClient.integer(value["max_anchor_age_blocks"]), age > 0 else { throw Failure.invalidResponse }
        guard difficulty <= 12, (1...14).contains(logN), (1...8).contains(r), p == 1 else { throw Failure.resourceLimit }
        var salt = Data()
        if let hex = value["challenge_salt_hex"] as? String {
            guard hex.count <= 128, let decoded = Data(hexadecimal: hex) else { throw Failure.invalidResponse }; salt = decoded
        } else if !(value["challenge_salt_hex"] is NSNull) { throw Failure.invalidResponse }
        var bigHeight = height.bigEndian
        let challenge = Data("iroha:accounts:faucet:pow:v1".utf8) + TairaClient.networkBytes + Data(account.utf8)
            + withUnsafeBytes(of: &bigHeight) { Data($0) } + Data(hexadecimal: hash)! + salt
        return Puzzle(height: height, difficulty: difficulty, n: 1 << logN, r: UInt32(r), p: UInt32(p), challenge: Data(SHA256.hash(data: challenge)))
    }
    /// The only limit on a claim's work. A slow device simply takes longer, so time
    /// is no limit. At the hardest puzzle `puzzle` accepts (12 bits) a claim runs out
    /// with probability e^-16; at 10 bits, e^-64.
    static let maximumTries: UInt64 = 65_536
    struct SolveStretch: Sendable, Equatable { let solution: Data?; let next: UInt64 }
    /// Tries nonces from `first` until one solves the puzzle or `end` passes. Passing
    /// `end` only ends this stretch; always makes at least one try.
    static func solve(_ puzzle: Puzzle, from first: UInt64 = 0, until end: TimeInterval = .infinity,
                      uptime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, scrypt: Scrypt) throws -> SolveStretch {
        var nonce = first
        repeat {
            try Task.checkCancellation()
            guard nonce < maximumTries else { throw Failure.resourceLimit }
            let bytes = NexusTransferCodec.u64(nonce)
            let digest = try scrypt(bytes, puzzle.challenge, puzzle.n, puzzle.r, puzzle.p)
            guard digest.count == 32 else { throw Failure.invalidResponse }
            nonce += 1
            let whole = Int(puzzle.difficulty / 8), remainder = Int(puzzle.difficulty % 8)
            if digest.prefix(whole).allSatisfy({ $0 == 0 }) && (remainder == 0 || digest[whole] >> (8 - remainder) == 0) {
                return SolveStretch(solution: bytes, next: nonce)
            }
        } while uptime() < end
        return SolveStretch(solution: nil, next: nonce)
    }
    static func semanticHash(account: String, height: UInt64, nonce: String) -> String {
        let f = NexusTransferCodec.field
        let encoded = f(f(Data(account.utf8))) + f(NexusTransferCodec.u64(height)) + f(f(Data(nonce.utf8)))
        var hash = Blake2b.hash256(Data("iroha:accounts:faucet:claim:v1\0".utf8) + encoded)
        hash[hash.count - 1] |= 1; return hash.hexadecimal
    }

    private static func send(_ input: URLRequest, maximum: Int) async throws -> Response {
        guard input.url?.scheme == "https", input.url?.host == "taira.sora.org", input.url?.port == nil,
              input.url?.user == nil, input.url?.password == nil else { throw Failure.wrongNetwork }
        var request = input; request.timeoutInterval = 25; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil; config.urlCache = nil
        let session = URLSession(configuration: config, delegate: FaucetNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.url == request.url else { throw Failure.invalidResponse }
        let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        guard response.expectedContentLength <= Int64(maximum) else { throw Failure.invalidResponse }
        // Error responses need not be JSON (e.g. ingress rate limiting).
        if [200, 202].contains(http.statusCode), http.mimeType != "application/json" { throw Failure.invalidResponse }
        var data = Data()
        for try await byte in stream { guard data.count < maximum else { throw Failure.invalidResponse }; data.append(byte) }
        return Response(data: data, statusCode: http.statusCode, retryAfterSeconds: retry)
    }
}

private final class FaucetNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
