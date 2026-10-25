import CryptoKit
import Foundation
import XCTest
@testable import NexusTransferCodec

final class TairaFaucetClientTests: XCTestCase {
    private let account = "testuﾛ1PﾍeｸﾊVZeｸYjﾛABRiﾕLｱｦｺjMﾀMAdYqﾊﾊCﾇｿﾓfreﾙ9M8GPH"
    private let publicKey = Data(hexadecimal: "b30c10e8c82f8b8c80ad83594956f27e09ac75b461eb19694135f437ccfdb4b5")!
    private let now: UInt64 = 1_791_874_348_510
    private let requestID = "7582fe6c111c4ac1b031f8c76db1a3f9442512bb6c50448289dad334fedb9084"
    private func fixture() throws -> Data { try Data(contentsOf: Bundle.module.url(forResource: "faucet-prepared", withExtension: "json")!) }
    private func puzzle() -> [String: Any] { [
        "algorithm": "scrypt-leading-zero-bits-v1", "network_id": TairaClient.networkLiteral,
        "chain_discriminant": 369, "difficulty_bits": 8, "anchor_height": 72,
        "anchor_block_hash_hex": String(repeating: "01", count: 32), "challenge_salt_hex": NSNull(),
        "scrypt_log_n": 13, "scrypt_r": 8, "scrypt_p": 1, "max_anchor_age_blocks": 6] }
    private func policy() -> [String: Any] { ["schema_version": 1, "network_id": TairaClient.networkLiteral,
        "network_prefix": 369, "authority": TairaFaucetClient.authority,
        "asset_definition_id": TairaClient.xorDefinition, "amount": TairaFaucetClient.amount] }
    private func validate(_ data: Data, key: Data? = nil, target: String? = nil) throws -> String {
        let original = try TairaFaucetClient.object(fixture())
        return try TairaFaucetClient.validatePrepared(data, account: target ?? account, publicKey: key ?? publicKey,
            claim: original["claim"] as! [String: Any], binding: original["binding"] as! [String: Any],
            semantic: original["semantic_hash_hex"] as! String, now: now)
    }
    func testRealFaucetFixtureSignatureAndExactClaimValidate() throws {
        let data = try fixture(), root = try TairaFaucetClient.object(data)
        XCTAssertEqual(try validate(data), root["transaction_hash_hex"] as? String)
        XCTAssertEqual(TairaFaucetClient.semanticHash(account: account, height: 72, nonce: "0601000000000000"), root["semantic_hash_hex"] as? String)
    }
    func testPreparedRejectsAddressKeyAmountBindingAndWireSubstitution() throws {
        let data = try fixture()
        XCTAssertThrowsError(try validate(data, key: Data(repeating: 3, count: 32)))
        XCTAssertThrowsError(try validate(data, target: "different"))
        for field in ["account_id", "asset_definition_id", "asset_id", "amount", "transaction_hash_hex", "semantic_hash_hex", "signed_transaction_wire_sha256"] {
            var changed = try TairaFaucetClient.object(data); changed[field] = "wrong"
            XCTAssertThrowsError(try validate(TairaFaucetClient.json(changed)), field)
        }
        var changed = try TairaFaucetClient.object(data)
        var binding = changed["binding"] as! [String: Any]; binding["request_id"] = String(repeating: "a", count: 64); changed["binding"] = binding
        XCTAssertThrowsError(try validate(TairaFaucetClient.json(changed)))
        changed = try TairaFaucetClient.object(data)
        var wire = Data(hexadecimal: changed["signed_transaction_wire_hex"] as! String)!
        wire[40] ^= 1
        changed["signed_transaction_wire_hex"] = wire.hexadecimal
        changed["signed_transaction_wire_sha256"] = Data(SHA256.hash(data: wire)).hexadecimal
        XCTAssertThrowsError(try validate(TairaFaucetClient.json(changed)))
    }
    func testPuzzleNetworkAndResourceBoundsBeforeScrypt() throws {
        var value = puzzle(); value["network_id"] = "wrong"
        XCTAssertThrowsError(try TairaFaucetClient.puzzle(value, account: account)) { XCTAssertEqual($0 as? TairaFaucetClient.Failure, .wrongNetwork) }
        for (key, number) in [("difficulty_bits", 13), ("scrypt_log_n", 15), ("scrypt_r", 9), ("scrypt_p", 2)] {
            value = puzzle(); value[key] = number
            XCTAssertThrowsError(try TairaFaucetClient.puzzle(value, account: account)) { XCTAssertEqual($0 as? TairaFaucetClient.Failure, .resourceLimit) }
        }
        value = puzzle(); value["scrypt_log_n"] = true
        XCTAssertThrowsError(try TairaFaucetClient.puzzle(value, account: account))
    }
    func testScryptChallengeBindsNetworkAddressAndAnchorAndUsesLittleEndianNonce() throws {
        let proof = try TairaFaucetClient.puzzle(puzzle(), account: account)
        let other = try TairaFaucetClient.puzzle(puzzle(), account: account + "x")
        XCTAssertNotEqual(proof.challenge, other.challenge)
        let expected = TairaClient.networkBytes + Data(account.utf8) + Data([0, 0, 0, 0, 0, 0, 0, 72]) + Data(repeating: 1, count: 32)
        XCTAssertEqual(proof.challenge, Data(SHA256.hash(data: Data("iroha:accounts:faucet:pow:v1".utf8) + expected)))
        let nonce = try TairaFaucetClient.solve(proof) { nonce, salt, n, r, p in
            XCTAssertEqual(salt, proof.challenge); XCTAssertEqual(n, 8192); XCTAssertEqual(r, 8); XCTAssertEqual(p, 1)
            return Data(repeating: nonce == Data([2, 1, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32)
        }
        XCTAssertEqual(nonce, Data([2, 1, 0, 0, 0, 0, 0, 0]))
    }
    func testPrepareSubmitExactBytesOnceAndReconcileApplied() async throws {
        let data = try fixture(), policy = try TairaFaucetClient.json(policy()), puzzle = try TairaFaucetClient.json(puzzle())
        let recorded = FaucetRequests()
        let root = try TairaFaucetClient.object(data), hash = root["transaction_hash_hex"] as! String
        let response = try TairaFaucetClient.json(["schema": "iroha.prepared-transaction-submit.v1", "operation": "faucet",
            "transaction_hash_hex": hash, "binding": root["binding"]!, "outcome": "Pending"])
        let status = try TairaFaucetClient.json(["hash": hash, "scope": "global", "resolved_from": "state", "status": ["kind": "Applied", "block_height": 73]])
        let client = TairaFaucetClient(scrypt: { nonce, _, _, _, _ in Data(repeating: nonce == Data([6, 1, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32) }, transport: { request, _ in
            await recorded.append(request)
            switch request.url!.path {
            case "/v1/accounts/faucet/policy": return .init(data: policy)
            case "/v1/accounts/faucet/puzzle": return .init(data: puzzle)
            case "/v1/accounts/faucet/prepare": return .init(data: data)
            case "/v1/accounts/faucet": XCTAssertEqual(request.httpBody, data); return .init(data: response, statusCode: 202)
            default: return .init(data: status)
            }
        }, clock: { 1_791_874_348_510 }, requestID: { "7582fe6c111c4ac1b031f8c76db1a3f9442512bb6c50448289dad334fedb9084" })
        let claim = try await client.prepare(account: account, publicKey: publicKey)
        XCTAssertEqual(claim.transactionHash, hash)
        let sent = try await client.submit(claim); XCTAssertEqual(sent.state, .pending)
        do { _ = try await client.submit(claim); XCTFail("submitted twice") } catch { XCTAssertEqual(error as? TairaFaucetClient.Failure, .alreadySubmitted) }
        let outcome = try await client.resume(transactionHash: hash, timeout: 0)
        XCTAssertEqual(outcome.state, .applied(blockHeight: 73))
        let requests = await recorded.requests
        XCTAssertEqual(requests.filter { $0.url?.path == "/v1/accounts/faucet" }.count, 1)
        XCTAssertEqual(requests.last?.httpMethod, "GET")
    }
    func testStatus404PendingCachedAppliedAndWrongHashNeverReportSuccess() async throws {
        let hash = String(repeating: "01", count: 32)
        let scrypt: TairaFaucetClient.Scrypt = { _, _, _, _, _ in Data() }
        let missing = TairaFaucetClient(scrypt: scrypt, transport: { _, _ in .init(data: Data(), statusCode: 404) })
        let absent = try await missing.resume(transactionHash: hash, timeout: 0); XCTAssertEqual(absent.state, .pending)
        let pending = try TairaFaucetClient.json(["hash": hash, "scope": "global", "resolved_from": "queue", "status": ["kind": "Queued"]])
        let queued = TairaFaucetClient(scrypt: scrypt, transport: { _, _ in .init(data: pending) })
        let waiting = try await queued.resume(transactionHash: hash, timeout: 0); XCTAssertEqual(waiting.state, .pending)
        for changed in [
            ["hash": hash, "scope": "global", "resolved_from": "cache", "status": ["kind": "Applied", "block_height": 73]],
            ["hash": hash, "scope": "global", "resolved_from": "cache", "status": ["kind": "Rejected"]],
            ["hash": String(repeating: "03", count: 32), "scope": "global", "resolved_from": "state", "status": ["kind": "Applied", "block_height": 73]]
        ] as [[String: Any]] {
            let data = try TairaFaucetClient.json(changed)
            let client = TairaFaucetClient(scrypt: scrypt, transport: { _, _ in .init(data: data) })
            do { _ = try await client.resume(transactionHash: hash, timeout: 0); XCTFail("invalid finality accepted") } catch { XCTAssertEqual(error as? TairaFaucetClient.Failure, .invalidResponse) }
        }
        let unavailable = TairaFaucetClient(scrypt: scrypt, transport: { _, _ in throw URLError(.notConnectedToInternet) })
        let offline = try await unavailable.resume(transactionHash: hash, timeout: 0); XCTAssertEqual(offline.state, .pending)
    }
    func testAmbiguousSubmitRetainsKnownHashAndCannotResubmit() async throws {
        let data = try fixture(), policy = try TairaFaucetClient.json(policy()), puzzle = try TairaFaucetClient.json(puzzle())
        for mode in 0..<3 {
            let recorded = FaucetRequests()
            let client = TairaFaucetClient(scrypt: { nonce, _, _, _, _ in Data(repeating: nonce == Data([6, 1, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32) }, transport: { request, _ in
                await recorded.append(request)
                switch request.url!.path {
                case "/v1/accounts/faucet/policy": return .init(data: policy)
                case "/v1/accounts/faucet/puzzle": return .init(data: puzzle)
                case "/v1/accounts/faucet/prepare": return .init(data: data)
                default:
                    if mode == 0 { throw URLError(.timedOut) }
                    if mode == 1 { return .init(data: Data("{}".utf8)) }
                    return .init(data: Data(), statusCode: 429, retryAfterSeconds: 75)
                }
            }, clock: { 1_791_874_348_510 }, requestID: { "7582fe6c111c4ac1b031f8c76db1a3f9442512bb6c50448289dad334fedb9084" })
            let claim = try await client.prepare(account: account, publicKey: publicKey)
            do {
                let outcome = try await client.submit(claim)
                XCTAssertNotEqual(mode, 2); XCTAssertEqual(outcome.state, .pending)
                XCTAssertEqual(outcome.transactionHash, claim.transactionHash)
            } catch { XCTAssertEqual(mode, 2); XCTAssertEqual(error as? TairaFaucetClient.Failure, .rateLimited(retryAfterSeconds: 75)) }
            do { _ = try await client.submit(claim); XCTFail("redispatched ambiguous request") } catch { XCTAssertEqual(error as? TairaFaucetClient.Failure, .alreadySubmitted) }
            let requests = await recorded.requests
            XCTAssertEqual(requests.filter { $0.url?.path == "/v1/accounts/faucet" }.count, 1)
        }
    }
    func testRateLimitKeepsCooldownAndRejectedIsDistinct() async throws {
        let hash = String(repeating: "01", count: 32)
        let limited = TairaFaucetClient(scrypt: { _, _, _, _, _ in Data() }, transport: { _, _ in .init(data: Data(), statusCode: 429, retryAfterSeconds: 120) })
        do { _ = try await limited.resume(transactionHash: hash, timeout: 0); XCTFail("rate limit ignored") } catch { XCTAssertEqual(error as? TairaFaucetClient.Failure, .rateLimited(retryAfterSeconds: 120)) }
        let data = try TairaFaucetClient.json(["hash": hash, "scope": "global", "resolved_from": "state", "status": ["kind": "Rejected"]])
        let rejected = TairaFaucetClient(scrypt: { _, _, _, _, _ in Data() }, transport: { _, _ in .init(data: data) })
        let outcome = try await rejected.resume(transactionHash: hash, timeout: 0)
        if case .rejected = outcome.state { } else { XCTFail("rejection was not terminal") }
    }
    func testCancellationBeforeRequestAndInsidePoW() async throws {
        let client = TairaFaucetClient(scrypt: { _, _, _, _, _ in XCTFail("unexpected scrypt"); return Data() }, transport: { _, _ in XCTFail("unexpected request"); return .init(data: Data()) })
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await client.prepare(account: account, publicKey: publicKey) }
        task.cancel()
        do { _ = try await task.value; XCTFail("cancel ignored") } catch is CancellationError { }
        let proof = try TairaFaucetClient.puzzle(puzzle(), account: account)
        let started = expectation(description: "proof started")
        let work = Task.detached { try TairaFaucetClient.solve(proof) { nonce, _, _, _, _ in if nonce == Data(repeating: 0, count: 8) { started.fulfill() }; Thread.sleep(forTimeInterval: 0.05); return Data(repeating: 255, count: 32) } }
        await fulfillment(of: [started], timeout: 1)
        work.cancel()
        do { _ = try await work.value; XCTFail("proof cancel ignored") } catch is CancellationError { }
    }
}

private actor FaucetRequests {
    var requests: [URLRequest] = []
    func append(_ request: URLRequest) { requests.append(request) }
}
