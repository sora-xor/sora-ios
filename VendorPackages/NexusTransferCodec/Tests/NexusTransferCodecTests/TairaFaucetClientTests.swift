import CryptoKit
import Foundation
import XCTest
@testable import NexusTransferCodec

final class TairaFaucetClientTests: XCTestCase {
    private let account = "testuﾛ1NhｶﾅmVﾛFnｽﾔSvaWﾉﾇ9ｹLBﾛhmMﾙｸHﾈﾁﾍｺoﾀpbHjｵ7S9LE9"
    private let publicKey = Data(hexadecimal: "076247e3e97ab20c74cb766d948d0cb19b8f3b529112e4f80d06d32681937f5d")!
    private let now: UInt64 = 1_793_578_885_193
    private let requestID = "6ddfcc7d143e4c88a6232812ab8de1d45038167b3baf4aedae245d6f534824f4"
    private func fixture() throws -> Data { try Data(contentsOf: Bundle.module.url(forResource: "faucet-prepared", withExtension: "json")!) }
    private func puzzle() -> [String: Any] { [
        "algorithm": "scrypt-leading-zero-bits-v1", "network_id": TairaClient.networkLiteral,
        "chain_discriminant": 369, "difficulty_bits": 8, "anchor_height": 10085,
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
        XCTAssertEqual(TairaFaucetClient.semanticHash(account: account, height: 10085, nonce: "3800000000000000"), root["semantic_hash_hex"] as? String)
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
        let expected = TairaClient.networkBytes + Data(account.utf8) + Data([0, 0, 0, 0, 0, 0, 0x27, 0x65]) + Data(repeating: 1, count: 32)
        XCTAssertEqual(proof.challenge, Data(SHA256.hash(data: Data("iroha:accounts:faucet:pow:v1".utf8) + expected)))
        let stretch = try TairaFaucetClient.solve(proof) { nonce, salt, n, r, p in
            XCTAssertEqual(salt, proof.challenge); XCTAssertEqual(n, 8192); XCTAssertEqual(r, 8); XCTAssertEqual(p, 1)
            return Data(repeating: nonce == Data([2, 1, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32)
        }
        XCTAssertEqual(stretch.solution, Data([2, 1, 0, 0, 0, 0, 0, 0]))
    }
    func testSolveHasNoTimeLimit() throws {
        let proof = try TairaFaucetClient.puzzle(puzzle(), account: account)
        var now: TimeInterval = 0
        // Every read of the clock is an hour later, and 259 tries still end in a solution.
        let stretch = try TairaFaucetClient.solve(proof, uptime: { now += 3600; return now }) { nonce, _, _, _, _ in
            Data(repeating: nonce == Data([2, 1, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32)
        }
        XCTAssertEqual(stretch.solution, Data([2, 1, 0, 0, 0, 0, 0, 0]))
        XCTAssertGreaterThan(now, 900_000)
    }
    func testSolveRunsOutOfTriesExactlyAtTheBound() throws {
        XCTAssertEqual(TairaFaucetClient.maximumTries, 65_536)
        let proof = try TairaFaucetClient.puzzle(puzzle(), account: account)
        var tries = 0, last = Data()
        XCTAssertThrowsError(try TairaFaucetClient.solve(proof) { nonce, _, _, _, _ in
            tries += 1; last = nonce
            return Data(repeating: 255, count: 32)
        }) { XCTAssertEqual($0 as? TairaFaucetClient.Failure, .resourceLimit) }
        XCTAssertEqual(tries, 65_536)
        XCTAssertEqual(last, Data([255, 255, 0, 0, 0, 0, 0, 0]))
    }
    func testAStretchOnlyPausesTheSolveAndAlwaysMakesATry() throws {
        let proof = try TairaFaucetClient.puzzle(puzzle(), account: account)
        var tried: [Data] = []
        let record: TairaFaucetClient.Scrypt = { _, _, _, _, _ in Data(repeating: 255, count: 32) }
        let first = try TairaFaucetClient.solve(proof, until: -1) { nonce, a, b, c, d in tried.append(nonce); return try record(nonce, a, b, c, d) }
        XCTAssertEqual(first, .init(solution: nil, next: 1))
        let second = try TairaFaucetClient.solve(proof, from: first.next, until: -1) { nonce, a, b, c, d in tried.append(nonce); return try record(nonce, a, b, c, d) }
        XCTAssertEqual(second, .init(solution: nil, next: 2))
        XCTAssertEqual(tried, [Data([0, 0, 0, 0, 0, 0, 0, 0]), Data([1, 0, 0, 0, 0, 0, 0, 0])])
        let end = try TairaFaucetClient.solve(proof, from: TairaFaucetClient.maximumTries - 1, until: -1) { _, _, _, _, _ in Data(repeating: 0, count: 32) }
        XCTAssertEqual(end, .init(solution: Data([255, 255, 0, 0, 0, 0, 0, 0]), next: TairaFaucetClient.maximumTries))
        XCTAssertThrowsError(try TairaFaucetClient.solve(proof, from: end.next, until: -1) { _, _, _, _, _ in XCTFail("tried past the bound"); return Data() }) {
            XCTAssertEqual($0 as? TairaFaucetClient.Failure, .resourceLimit)
        }
    }
    func testFailureMessageBlamesTheConnectionOnlyForAFailedRequest() throws {
        let connection = "Could not get test XOR. Check your connection and try again."
        let solve = "Your test XOR could not be prepared on this device. Please try again later."
        let other = "The faucet request was not completed. Please try again."
        XCTAssertEqual(TairaFaucetClient.failureMessage(for: TairaFaucetClient.Failure.resourceLimit), solve)
        for code in [URLError.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost] {
            XCTAssertEqual(TairaFaucetClient.failureMessage(for: URLError(code)), connection)
        }
        for failure in [TairaFaucetClient.Failure.rejectedHTTP(400), .rejectedHTTP(503), .invalidResponse, .wrongNetwork, .expired, .alreadySubmitted] {
            XCTAssertEqual(TairaFaucetClient.failureMessage(for: failure), other)
        }
        XCTAssertEqual(TairaFaucetClient.failureMessage(for: CocoaError(.fileWriteOutOfSpace)), other)
        // Every message is in the catalogs: English, and the languages that do not fall back to it.
        let catalogs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("SoraPassport/SoraLocalizable")
        func catalog(_ language: String) throws -> [String: String] {
            let url = catalogs.appendingPathComponent(language + ".lproj/Localizable.strings")
            return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], language)
        }
        let english = try catalog("en")
        for key in [connection, solve, other] { XCTAssertEqual(english[key], key) }
        let progress = "Preparing your test XOR… %@\nThis can take a few minutes."
        XCTAssertEqual(english[progress], progress)
        let languages = try FileManager.default.contentsOfDirectory(atPath: catalogs.path).filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) }
        XCTAssertEqual(languages.count, 33)
        for language in languages where language != "en" {
            let table = try catalog(language)
            if ["akk", "egy-Egyp"].contains(language) {
                XCTAssertNil(table[solve], language); XCTAssertNil(table[progress], language)
            } else {
                let translatedSolve = try XCTUnwrap(table[solve], language), translatedProgress = try XCTUnwrap(table[progress], language)
                XCTAssertNotEqual(translatedSolve, solve, language); XCTAssertNotEqual(translatedProgress, progress, language)
                XCTAssertEqual(translatedProgress.components(separatedBy: "%@").count, 2, language)
                XCTAssertEqual(translatedProgress.components(separatedBy: "\n").count, 2, language)
                XCTAssertFalse(translatedSolve.contains("%"), language)
            }
        }
    }
    // MARK: A whole prepare, against the fixture's exact claim (anchor 10085, nonce 0x38).
    private var solved: Data { Data([0x38, 0, 0, 0, 0, 0, 0, 0]) }
    private func puzzleAnswer(anchor: Int) throws -> TairaFaucetClient.Response {
        var value = puzzle(); value["anchor_height"] = anchor
        return .init(data: try TairaFaucetClient.json(value))
    }
    private func challenge(anchor: Int) throws -> Data {
        var value = puzzle(); value["anchor_height"] = anchor
        return try TairaFaucetClient.puzzle(value, account: account).challenge
    }
    private func refusal(_ code: String, status: Int = 400) throws -> TairaFaucetClient.Response {
        .init(data: try TairaFaucetClient.json(["code": code, "message": "refused"]), statusCode: status)
    }
    private func claimClient(puzzles: @escaping @Sendable (Int) throws -> TairaFaucetClient.Response,
                             refusals: [TairaFaucetClient.Response] = [], recorded: FaucetRequests,
                             pacing: TairaFaucetClient.SolvePacing = .init(),
                             scrypt: @escaping TairaFaucetClient.Scrypt) throws -> TairaFaucetClient {
        let data = try fixture(), policy = try TairaFaucetClient.json(policy())
        return TairaFaucetClient(scrypt: scrypt, transport: { request, _ in
            let path = request.url!.path, earlier = await recorded.count(path: path)
            await recorded.append(request)
            switch path {
            case "/v1/accounts/faucet/policy": return .init(data: policy)
            case "/v1/accounts/faucet/puzzle": return try puzzles(earlier)
            case "/v1/accounts/faucet/prepare": return earlier < refusals.count ? refusals[earlier] : .init(data: data)
            default: XCTFail("unexpected \(path)"); return .init(data: Data())
            }
        }, clock: { 1_793_578_885_193 }, requestID: { "6ddfcc7d143e4c88a6232812ab8de1d45038167b3baf4aedae245d6f534824f4" }, pacing: pacing)
    }
    private func anchors(_ requests: [URLRequest]) throws -> [Int] {
        try requests.filter { $0.url?.path == "/v1/accounts/faucet/prepare" }.map { request in
            let body = try TairaFaucetClient.object(try XCTUnwrap(request.httpBody))
            return try XCTUnwrap((body["claim"] as? [String: Any])?["pow_anchor_height"] as? Int)
        }
    }
    func testSlowSolveStillEndsInAClaim() async throws {
        let answer = try puzzleAnswer(anchor: 10085), solved = solved, recorded = FaucetRequests()
        let hash = try TairaFaucetClient.object(fixture())["transaction_hash_hex"] as? String
        // Every read of the clock is 40 s later: hours of solving, in one try per stretch.
        let uptime = FaucetLog<TimeInterval>(), tries = FaucetLog<Data>()
        let pacing = TairaFaucetClient.SolvePacing(uptime: { uptime.append(uptime.count == 0 ? 40 : uptime.last! + 40); return uptime.last! })
        let client = try claimClient(puzzles: { _ in answer }, recorded: recorded, pacing: pacing) { nonce, _, _, _, _ in
            tries.append(nonce)
            // A solve that lost its place ends here with the wrong nonce, and fails, instead of never ending.
            return Data(repeating: nonce == solved || tries.count > 1000 ? 0 : 255, count: 32)
        }
        let claim = try await client.prepare(account: account, publicKey: publicKey)
        XCTAssertEqual(claim.transactionHash, hash)
        XCTAssertEqual(tries.count, 57)
        XCTAssertGreaterThan(try XCTUnwrap(uptime.last), 3600)
    }
    func testPuzzleIsReadAgainDuringASolveAndNoTryIsRepeated() async throws {
        let old = try puzzleAnswer(anchor: 10084), new = try puzzleAnswer(anchor: 10085), newest = try challenge(anchor: 10085), solved = solved
        let tries = FaucetLog<Data>(), recorded = FaucetRequests()
        let client = try claimClient(puzzles: { $0 < 5 ? old : new }, recorded: recorded,
                                     pacing: .init(puzzleRefresh: 0)) { nonce, salt, _, _, _ in
            tries.append(nonce)
            return Data(repeating: (nonce == solved && salt == newest) || tries.count > 1000 ? 0 : 255, count: 32)
        }
        let claim = try await client.prepare(account: account, publicKey: publicKey)
        XCTAssertEqual(claim.account, account)
        XCTAssertEqual(tries.all, (UInt64(0)...0x38).map { Data([UInt8($0), 0, 0, 0, 0, 0, 0, 0]) })
        let requests = await recorded.requests
        XCTAssertEqual(try anchors(requests), [10085])
    }
    func testAFailedPuzzleReadCostsTheSolveNothing() async throws {
        let answer = try puzzleAnswer(anchor: 10085), older = try puzzleAnswer(anchor: 10000), solved = solved
        let garbage = TairaFaucetClient.Response(data: Data("not json".utf8)), limited = TairaFaucetClient.Response(data: Data(), statusCode: 429, retryAfterSeconds: 60)
        let tooHard = try { () throws -> TairaFaucetClient.Response in
            var value = self.puzzle(); value["anchor_height"] = 10090; value["difficulty_bits"] = 13
            return .init(data: try TairaFaucetClient.json(value))
        }()
        let recorded = FaucetRequests()
        let client = try claimClient(puzzles: { read in
            switch read % 5 {
            case 0: return answer
            case 1: throw URLError(.timedOut)
            case 2: return garbage
            case 3: return limited
            default: return read % 2 == 0 ? older : tooHard
            }
        }, recorded: recorded, pacing: .init(puzzleRefresh: 0)) { nonce, _, _, _, _ in
            Data(repeating: nonce == solved ? 0 : 255, count: 32)
        }
        _ = try await client.prepare(account: account, publicKey: publicKey)
        let requests = await recorded.requests
        XCTAssertEqual(try anchors(requests), [10085])
    }
    func testALaggingNodeCannotMoveTheSolveToAnOlderAnchor() async throws {
        let new = try puzzleAnswer(anchor: 10085), older = try puzzleAnswer(anchor: 10084), newest = try challenge(anchor: 10085), solved = solved
        let recorded = FaucetRequests()
        let client = try claimClient(puzzles: { $0 == 0 ? new : older }, recorded: recorded,
                                     pacing: .init(puzzleRefresh: 0)) { nonce, salt, _, _, _ in
            Data(repeating: nonce == solved && salt == newest ? 0 : 255, count: 32)
        }
        let claim = try await client.prepare(account: account, publicKey: publicKey)
        XCTAssertEqual(claim.account, account)
        let requests = await recorded.requests
        XCTAssertEqual(try anchors(requests), [10085])
    }
    func testAProofTheChainMovedPastIsSolvedAgainOnANewPuzzle() async throws {
        for code in ["faucet_pow_anchor_stale", "faucet_pow_anchor_unknown", "faucet_pow_anchor_out_of_range", "faucet_pow_solution_invalid"] {
            let old = try puzzleAnswer(anchor: 10000), new = try puzzleAnswer(anchor: 10085)
            let oldChallenge = try challenge(anchor: 10000), newChallenge = try challenge(anchor: 10085), solved = solved
            let recorded = FaucetRequests()
            let client = try claimClient(puzzles: { $0 == 0 ? old : new }, refusals: [try refusal(code)], recorded: recorded,
                                         pacing: .init(puzzleRefresh: .infinity)) { nonce, salt, _, _, _ in
                let hit = salt == oldChallenge ? nonce == Data([3, 0, 0, 0, 0, 0, 0, 0]) : salt == newChallenge && nonce == solved
                return Data(repeating: hit ? 0 : 255, count: 32)
            }
            let claim = try await client.prepare(account: account, publicKey: publicKey)
            XCTAssertEqual(claim.account, account)
            let requests = await recorded.requests
            XCTAssertEqual(try anchors(requests), [10000, 10085], code)
        }
    }
    func testRefusalsEndAfterTheLimit() async throws {
        let answer = try puzzleAnswer(anchor: 10085), recorded = FaucetRequests()
        let refusals = try Array(repeating: refusal("faucet_pow_anchor_stale"), count: 20)
        let client = try claimClient(puzzles: { _ in answer }, refusals: refusals, recorded: recorded,
                                     pacing: .init(puzzleRefresh: .infinity)) { _, _, _, _, _ in Data(repeating: 0, count: 32) }
        do { _ = try await client.prepare(account: account, publicKey: publicKey); XCTFail("refused for ever") } catch {
            XCTAssertEqual(error as? TairaFaucetClient.Failure, .rejectedHTTP(400))
        }
        let requests = await recorded.requests
        XCTAssertEqual(TairaFaucetClient.maximumRefusedProofs, 3)
        XCTAssertEqual(try anchors(requests).count, 4)
    }
    func testAnyOtherRefusalEndsTheClaimAtOnce() async throws {
        let answer = try puzzleAnswer(anchor: 10085)
        for (refused, failure) in [
            (try refusal("faucet_invalid_request"), TairaFaucetClient.Failure.rejectedHTTP(400)),
            (.init(data: Data("<html>".utf8), statusCode: 400), .rejectedHTTP(400)),
            (try refusal("faucet_pow_anchor_stale", status: 500), .rejectedHTTP(500)),
            (.init(data: Data(), statusCode: 429, retryAfterSeconds: 9), .rateLimited(retryAfterSeconds: 9))
        ] as [(TairaFaucetClient.Response, TairaFaucetClient.Failure)] {
            let recorded = FaucetRequests()
            let client = try claimClient(puzzles: { _ in answer }, refusals: [refused], recorded: recorded) { _, _, _, _, _ in Data(repeating: 0, count: 32) }
            do { _ = try await client.prepare(account: account, publicKey: publicKey); XCTFail("refusal ignored") } catch {
                XCTAssertEqual(error as? TairaFaucetClient.Failure, failure)
            }
            let requests = await recorded.requests
            XCTAssertEqual(try anchors(requests).count, 1)
        }
    }
    func testCancellingAPrepareStopsTheSolveInsideAStretch() async throws {
        let answer = try puzzleAnswer(anchor: 10085), tries = FaucetLog<Data>(), handle = FaucetLog<Task<TairaFaucetClient.PreparedClaim, Error>>()
        // A stretch this long never ends by itself, so only the cancel can stop these tries. Without it they end at the cap.
        let cap = 5000
        let client = try claimClient(puzzles: { _ in answer }, recorded: FaucetRequests(), pacing: .init(puzzleRefresh: 3600)) { nonce, _, _, _, _ in
            while handle.count == 0 { Thread.sleep(forTimeInterval: 0.001) }
            tries.append(nonce)
            if tries.count == 3 { handle.last?.cancel() }
            Thread.sleep(forTimeInterval: 0.002)
            return Data(repeating: tries.count >= cap ? 0 : 255, count: 32)
        }
        let account = account, publicKey = publicKey
        let task = Task { try await client.prepare(account: account, publicKey: publicKey) }
        handle.append(task)
        do { _ = try await task.value; XCTFail("cancel ignored") } catch is CancellationError { }
        let after = tries.count
        XCTAssertGreaterThanOrEqual(after, 3)
        XCTAssertLessThan(after, cap)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(tries.count, after)
    }
    func testPrepareSubmitExactBytesOnceAndReconcileApplied() async throws {
        let data = try fixture(), policy = try TairaFaucetClient.json(policy()), puzzle = try TairaFaucetClient.json(puzzle())
        let recorded = FaucetRequests()
        let root = try TairaFaucetClient.object(data), hash = root["transaction_hash_hex"] as! String
        let response = try TairaFaucetClient.json(["schema": "iroha.prepared-transaction-submit.v1", "operation": "faucet",
            "transaction_hash_hex": hash, "binding": root["binding"]!, "outcome": "Pending"])
        let status = try TairaFaucetClient.json(["hash": hash, "scope": "global", "resolved_from": "state", "status": ["kind": "Applied", "block_height": 73]])
        let client = TairaFaucetClient(scrypt: { nonce, _, _, _, _ in Data(repeating: nonce == Data([0x38, 0, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32) }, transport: { request, _ in
            await recorded.append(request)
            switch request.url!.path {
            case "/v1/accounts/faucet/policy": return .init(data: policy)
            case "/v1/accounts/faucet/puzzle": return .init(data: puzzle)
            case "/v1/accounts/faucet/prepare": return .init(data: data)
            case "/v1/accounts/faucet": XCTAssertEqual(request.httpBody, data); return .init(data: response, statusCode: 202)
            default: return .init(data: status)
            }
        }, clock: { 1_793_578_885_193 }, requestID: { "6ddfcc7d143e4c88a6232812ab8de1d45038167b3baf4aedae245d6f534824f4" })
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
            let client = TairaFaucetClient(scrypt: { nonce, _, _, _, _ in Data(repeating: nonce == Data([0x38, 0, 0, 0, 0, 0, 0, 0]) ? 0 : 255, count: 32) }, transport: { request, _ in
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
            }, clock: { 1_793_578_885_193 }, requestID: { "6ddfcc7d143e4c88a6232812ab8de1d45038167b3baf4aedae245d6f534824f4" })
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
    func count(path: String) -> Int { requests.filter { $0.url?.path == path }.count }
}

private final class FaucetLog<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []
    func append(_ value: Value) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    var all: [Value] { lock.lock(); defer { lock.unlock() }; return values }
    var count: Int { all.count }
    var last: Value? { all.last }
}
