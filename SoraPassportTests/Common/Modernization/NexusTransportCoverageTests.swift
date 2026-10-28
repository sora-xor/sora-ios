// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import XCTest
@testable import SoraPassport

/// The real Torii transport is exercised through URLProtocol; every request is intercepted.
/// Tests retain canonical endpoint admission and never call a live server or transaction signer.
final class NexusTransportCoverageTests: XCTestCase {
    private var session: URLSession!
    private var transport: NexusToriiClient!
    private var reader: NexusToriiReadClient!
    private let account = "testuﾛ1NｼXCeｱﾈﾁRｴUﾀPWﾏVｱrﾋhESEbpﾂｾ9Vﾗ5ﾇJｵavsｷ26TMSNN"
    private let receiver = "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
    private let asset = NexusAssetDefinitionIdentity.tairaXorDefinitionID
    private let txHash = String(repeating: "a", count: 64)
    private var configuration: NexusNetworkConfiguration { NexusNetworkConfiguration.taira! }

    override func setUp() {
        super.setUp()
        NexusTransportFixture.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NexusTransportFixture.self]
        session = URLSession(configuration: config)
        transport = NexusToriiClient(session: session)
        reader = NexusToriiReadClient(transport: transport)
    }
    override func tearDown() {
        session.invalidateAndCancel()
        reader = nil; transport = nil; session = nil
        super.tearDown()
    }
    private func routed(_ body: Any, type: String = "application/json", status: Int = 200, headers: [String: String] = [:]) -> [String: Any] {
        ["isError": false, "structuredContent": ["status": status, "content_type": type, "headers": headers, "body": body]]
    }
    private func answer(_ body: Any, type: String = "application/json") {
        NexusTransportFixture.configure(result: routed(body, type: type))
    }
    private func failure<T>(_ operation: () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await operation(); XCTFail("Untrusted response was accepted", file: file, line: line) }
        catch { }
    }
    private func health() async throws { try await transport.health(configuration: configuration) }
    private func assets(limit: Int = 100, offset: Int = 0, assetID: String? = nil) async throws -> NexusAccountAssetList {
        try await reader.accountAssets(account: account, configuration: configuration, asset: assetID ?? asset, limit: limit, offset: offset)
    }
    private func history(cursor: String? = nil) async throws -> NexusCursorHistoryPage {
        try await reader.transferHistoryPage(account: account, configuration: configuration, assetDefinitionID: asset, cursor: cursor)
    }
    private func movement(hash: String? = nil, index: Int = 0) -> [String: Any] {
        let hash = hash ?? txHash
        return ["id": "\(hash):\(account):\(index)", "source": "transaction", "type": "TRANSFER", "timestamp_ms": 1775260800000,
                "status": "SUCCESS", "result_ok": true, "direction": "outgoing", "account_id": account,
                "counterparty_account_id": receiver, "asset_id": "\(asset)#\(account)", "asset_definition_id": asset,
                "amount": "1.500000001", "tx_hash": hash, "block_height": 42, "block_index": 0, "movement_index": index]
    }

    func testHealthDiscoversCapabilityBeforeReadingAndPinsEveryRequest() async throws {
        answer("Healthy", type: "text/plain")
        try await health()
        let requests = NexusTransportFixture.requests
        XCTAssertEqual(requests.map { $0.method }, ["server/discover", "tools/list", "tools/call"])
        for request in requests {
            XCTAssertEqual(request.url, TairaDeploymentBinding.canonicalPublicMcpEndpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.protocolVersion, "2026-07-28")
            XCTAssertEqual(request.contentType, "application/json")
            XCTAssertEqual(request.accept, "application/json")
        }
        XCTAssertEqual(requests.last?.tool, "iroha.health")
    }
    func testHealthRejectsExtraWhitespaceAndWrongEmbeddedMediaType() async {
        answer("Healthy\n", type: "text/plain")
        await failure { try await self.health() }
        answer("Healthy", type: "application/json")
        await failure { try await self.health() }
    }
    func testAssetDefinitionReadBindsTheImmutableNativeAsset() async throws {
        answer(["id": asset])
        let definition = try await reader.xorAssetDefinition(configuration: configuration)
        XCTAssertEqual(definition.id, asset)
        XCTAssertEqual(NexusTransportFixture.requests.last?.tool, "iroha.assets.definitions.get")
        let args = try XCTUnwrap(NexusTransportFixture.requests.last?.arguments)
        XCTAssertEqual((args["path"] as? [String: String])?["definition_id"], asset)
    }
    func testAssetDefinitionRejectsContradictoryAliasWitnesses() async {
        for body: [String: Any] in [["id": asset, "alias": "val#universal"], ["id": asset, "name": "val"], ["id": "invalid"]] {
            answer(body)
            await failure { try await self.reader.xorAssetDefinition(configuration: self.configuration) }
        }
    }
    func testAccountAssetsPreserveExactQuantityAndAccountFilter() async throws {
        answer(["items": [["account_id": account, "asset": "\(asset)#\(account)", "quantity": "12345678901234567890.123456789"]], "total": 1, "next_cursor": NSNull()])
        let page = try await assets()
        XCTAssertEqual(page.items.first?.quantity.rawValue, "12345678901234567890.123456789")
        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.countMode, "exact")
        let arguments = try XCTUnwrap(NexusTransportFixture.requests.last?.arguments)
        XCTAssertEqual((arguments["path"] as? [String: String])?["account_id"], account)
        XCTAssertTrue((arguments["filter"] as? String)?.contains(asset) == true)
    }
    func testEmptyAccountAssetsRemainAnAuthoritativeEmptyPage() async throws {
        answer(["items": [], "total": 0, "next_cursor": NSNull()])
        let page = try await assets(limit: 1)
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertEqual(page.total, 0)
        XCTAssertFalse(page.hasMore)
    }
    func testAccountAssetsRejectTruncatedAndContradictoryCounts() async {
        for body: [String: Any] in [["items": [], "total": 1, "next_cursor": NSNull()], ["items": [], "total": 0, "next_cursor": "cursor"]] {
            answer(body)
            await failure { try await self.assets() }
        }
    }
    func testAssetLookupRejectsBadBoundsAndWrongAssetBeforeTransport() async {
        for limit in [0, 501] { await failure { try await self.assets(limit: limit) } }
        for offset in [-1, 1] { await failure { try await self.assets(offset: offset) } }
        await failure { try await self.assets(assetID: "xor#universal") }
        XCTAssertTrue(NexusTransportFixture.requests.isEmpty)
    }
    func testStatusReadPreservesGlobalFinalityEvidenceAndNormalizesQueryHash() async throws {
        answer(["hash": txHash, "scope": "global", "resolved_from": "state", "status": ["kind": "Applied", "block_height": 42]])
        let status = try await reader.status(hash: "0x" + txHash.uppercased(), configuration: configuration)
        XCTAssertEqual(status.hash, txHash)
        XCTAssertTrue(status.hasAuthoritativeGlobalResolution)
        let arguments = try XCTUnwrap(NexusTransportFixture.requests.last?.arguments)
        XCTAssertEqual((arguments["query"] as? [String: String])?["hash"], txHash)
    }
    func testStatusRejectsInvalidHashWithoutOpeningTransport() async {
        await failure { try await self.reader.status(hash: "not-a-hash", configuration: self.configuration) }
        XCTAssertTrue(NexusTransportFixture.requests.isEmpty)
    }
    func testHistoryPreservesExactMovementAndOpaqueCursor() async throws {
        answer(["items": [movement()], "next_cursor": "next_cursor"])
        let page = try await history()
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.amount.rawValue, "1.500000001")
        XCTAssertEqual(page.items.first?.sender, account)
        XCTAssertEqual(page.items.first?.receiver, receiver)
        XCTAssertEqual(page.items.first?.transactionHash, txHash)
        XCTAssertEqual(page.nextCursor, "next_cursor")
    }
    func testHistorySendsTheRequestedCursor() async throws {
        answer(["items": [], "next_cursor": NSNull()])
        _ = try await history(cursor: "opaque_cursor")
        XCTAssertEqual(NexusTransportFixture.requests.last?.arguments?["cursor"] as? String, "opaque_cursor")
    }
    func testHistoryRejectsDuplicateMovementIds() async {
        answer(["items": [movement(), movement()], "next_cursor": NSNull()])
        await failure { try await self.history() }
    }
    func testHistoryRejectsAProjectionForAnotherAccount() async {
        var row = movement(); row["account_id"] = receiver
        answer(["items": [row], "next_cursor": NSNull()])
        await failure { try await self.history() }
    }
    func testCommittedHistoryRequiresTheExactRequestedHash() async throws {
        answer(["items": [movement()], "next_cursor": NSNull()])
        let values = try await reader.committedXorTransfers(account: account, configuration: configuration, assetDefinitionID: asset, transactionHash: txHash)
        XCTAssertEqual(values.map(\.transactionHash), [txHash])
        XCTAssertTrue((NexusTransportFixture.requests.last?.arguments?["filter"] as? String)?.contains(txHash) == true)
        answer(["items": [movement(hash: String(repeating: "b", count: 64))], "next_cursor": NSNull()])
        await failure { try await self.reader.committedXorTransfers(account: self.account, configuration: self.configuration, assetDefinitionID: self.asset, transactionHash: self.txHash) }
    }
    func testAuthoritativeCommittedProofDistinguishesPresentAndAbsent() async throws {
        answer(["items": [movement()], "next_cursor": NSNull()])
        let present = try await reader.hasAuthoritativeCommittedTransaction(account: account, configuration: configuration, assetDefinitionID: asset, transactionHash: txHash)
        XCTAssertTrue(present)
        answer(["items": [], "next_cursor": NSNull()])
        let absent = try await reader.hasAuthoritativeCommittedTransaction(account: account, configuration: configuration, assetDefinitionID: asset, transactionHash: txHash)
        XCTAssertFalse(absent)
    }
    func testCommittedHistoryRejectsRepeatingPaginationInsteadOfLooping() async {
        answer(["items": [], "next_cursor": "same_cursor"])
        await failure { try await self.reader.committedXorTransfers(account: self.account, configuration: self.configuration, assetDefinitionID: self.asset, transactionHash: self.txHash) }
        XCTAssertEqual(NexusTransportFixture.requests.filter { $0.method == "tools/call" }.count, 2)
    }
    func testDiscoveryCanFindRequestedToolOnALaterPage() async throws {
        answer("Healthy", type: "text/plain")
        NexusTransportFixture.discoveryPages = [["tools": [], "nextCursor": "2"], ["tools": NexusTransportFixture.descriptors]]
        try await health()
        XCTAssertEqual(NexusTransportFixture.requests.map(\.method), ["server/discover", "tools/list", "tools/list", "tools/call"])
    }
    func testMissingAdvertisedToolNeverCallsTheReadRoute() async {
        answer("Healthy", type: "text/plain")
        NexusTransportFixture.discoveryPages = [["tools": []]]
        await failure { try await self.health() }
        XCTAssertFalse(NexusTransportFixture.requests.contains { $0.method == "tools/call" })
    }
    func testRepeatedDiscoveryCursorStopsWithoutCallingReadRoute() async {
        answer("Healthy", type: "text/plain")
        NexusTransportFixture.discoveryPages = [["tools": [], "nextCursor": "2"], ["tools": [], "nextCursor": "2"]]
        await failure { try await self.health() }
        XCTAssertEqual(NexusTransportFixture.requests.count, 3)
    }
    func testUnsupportedServerProtocolFailsBeforeToolDiscovery() async {
        NexusTransportFixture.discoveryResult = ["supportedVersions": ["1999-01-01"]]
        await failure { try await self.health() }
        XCTAssertEqual(NexusTransportFixture.requests.count, 1)
    }
    func testWrongResponseIdCannotSatisfyTheRequest() async {
        NexusTransportFixture.responseID = "different-request"
        await failure { try await self.health() }
        XCTAssertEqual(NexusTransportFixture.requests.count, 1)
    }
    func testJSONRPCErrorIsNotTreatedAsAResult() async {
        NexusTransportFixture.rpcError = ["code": -32603, "message": "unavailable"]
        await failure { try await self.health() }
    }
    func testOuterUnavailableStatusRetainsTypedDeploymentFailure() async {
        for code in [502, 503] {
            NexusTransportFixture.statusCode = code
            do { try await health(); XCTFail("Unavailable deployment was accepted") }
            catch NexusToriiError.deploymentUnavailable { }
            catch { XCTFail("Wrong error: \(error)") }
        }
    }
    func testMissingPublicMCPRouteRetainsTypedAdmissionFailure() async {
        NexusTransportFixture.statusCode = 404
        do { try await health(); XCTFail("Missing MCP route was accepted") }
        catch NexusToriiError.mcpNotEnabled { }
        catch { XCTFail("Wrong error: \(error)") }
    }
    func testWrongOuterMediaTypeIsRejectedBeforeDecoding() async {
        NexusTransportFixture.contentType = "text/html"
        await failure { try await self.health() }
    }
    func testOversizedDeclaredResponseIsRejectedBeforeParsing() async {
        NexusTransportFixture.extraHeaders = ["Content-Length": "2097153"]
        do { try await health(); XCTFail("Oversized response was accepted") }
        catch NexusToriiError.responseTooLarge { }
        catch { XCTFail("Wrong error: \(error)") }
    }
    func testEmbeddedRouteFailureCannotBecomeHealthy() async {
        NexusTransportFixture.configure(result: routed("Healthy", type: "text/plain", status: 500))
        await failure { try await self.health() }
    }
    func testIncompleteFanoutCannotSupplyAnAuthoritativeRead() async {
        NexusTransportFixture.configure(result: routed("Healthy", type: "text/plain", headers: ["x-iroha-fanout-routes-attempted": "2"]))
        await failure { try await self.health() }
    }
    func testMinamotoReadsRemainUnavailableBeforeNetworkLaunch() async {
        await failure { try await self.reader.xorAssetDefinition(configuration: .minamoto) }
        await failure { try await self.reader.status(hash: self.txHash, configuration: .minamoto) }
        XCTAssertTrue(NexusTransportFixture.requests.isEmpty)
    }
    private func appliedSubmission(hash: String? = nil) -> [String: Any] {
        let hash = hash ?? txHash
        return ["content": [["type": "text", "text": "http 200"]], "isError": false,
                "structuredContent": ["status": 200, "hash": hash, "terminal_kind": "Applied", "terminal_statuses": ["Applied"], "attempts": 2, "elapsed_ms": 17,
                    "submit": ["status": 202, "headers": ["content-type": "application/json", "x-iroha-entrypoint-hash": hash], "content_type": "application/json", "body": ["payload": ["entrypoint_hash": hash]]],
                    "final": ["status": 200, "headers": ["content-type": "application/json"], "content_type": "application/json", "body": ["hash": hash, "scope": "global", "resolved_from": "state", "status": ["kind": "Applied", "block_height": 42]]]]]
    }
    private func submit(bytes: Data = Data([1, 2, 3, 4]), hash: String? = nil) async throws -> NexusToriiSubmissionResult {
        try await transport.submit(signedNorito: bytes, idempotencyKey: UUID(), expectedHash: hash ?? txHash, configuration: configuration)
    }
    func testSubmitAndWaitDiscoversTheReviewedToolAndPreservesExactBytes() async throws {
        NexusTransportFixture.configure(result: appliedSubmission())
        let bytes = Data([1,2,3,4,0,255]), result = try await submit(bytes: bytes)
        guard case let .applied(applied) = result else { return XCTFail("Applied proof was lost") }
        XCTAssertEqual(applied.hash, txHash); XCTAssertEqual(applied.blockHeight, 42)
        XCTAssertEqual(NexusTransportFixture.requests.map(\.method), ["server/discover", "tools/list", "tools/call"])
        let request = try XCTUnwrap(NexusTransportFixture.requests.last)
        XCTAssertEqual(request.tool, "iroha.transactions.submit_and_wait")
        XCTAssertEqual(request.arguments?["body_base64"] as? String, bytes.base64EncodedString())
        XCTAssertEqual(request.arguments?["hash"] as? String, txHash)
        XCTAssertEqual(request.arguments?["status_accept"] as? String, "application/json")
        XCTAssertEqual(request.arguments?["timeout_ms"] as? Int, 120000)
        XCTAssertEqual(request.timeout, 135)
    }
    func testSubmitRejectsMissingBytesOrMalformedHashBeforeCallingTheTool() async {
        for (bytes, hash) in [(Data(), txHash), (Data([1]), "invalid"), (Data([1]), "0x" + txHash)] {
            NexusTransportFixture.reset(); NexusTransportFixture.configure(result: appliedSubmission())
            await failure { try await self.submit(bytes: bytes, hash: hash) }
            XCTAssertFalse(NexusTransportFixture.requests.contains { $0.method == "tools/call" })
        }
    }
    func testSubmissionCannotProceedWhenTheAdvertisedToolIsAbsent() async {
        NexusTransportFixture.discoveryPages = [["tools": NexusTransportFixture.descriptors.filter { ($0["name"] as? String) != "iroha.transactions.submit_and_wait" }]]
        await failure { try await self.submit() }
        XCTAssertFalse(NexusTransportFixture.requests.contains { $0.method == "tools/call" })
    }
    func testSubmissionRejectsADifferentAppliedTransaction() async {
        NexusTransportFixture.configure(result: appliedSubmission(hash: String(repeating: "b", count: 64)))
        do { _ = try await submit(); XCTFail("Foreign transaction accepted") }
        catch NexusToriiError.transactionHashMismatch { }
        catch { XCTFail("Wrong error: \(error)") }
        XCTAssertEqual(NexusTransportFixture.requests.filter { $0.method == "tools/call" }.count, 1)
    }
    func testRejectedAndExpiredSubmissionsAreNotRetried() async {
        for terminal in ["Rejected", "Expired"] {
            NexusTransportFixture.reset()
            var result = appliedSubmission(), structured = result["structuredContent"] as! [String: Any]
            structured["terminal_kind"] = terminal; result["structuredContent"] = structured
            NexusTransportFixture.configure(result: result)
            do { _ = try await submit(); XCTFail("Rejected transaction accepted") }
            catch NexusToriiError.server { }
            catch { XCTFail("Wrong error: \(error)") }
            XCTAssertEqual(NexusTransportFixture.requests.filter { $0.method == "tools/call" }.count, 1)
        }
    }
    func testReceiptWithoutGlobalFinalityCannotBecomeSuccessfulSubmission() async {
        var result = appliedSubmission(), structured = result["structuredContent"] as! [String: Any]
        structured.removeValue(forKey: "final"); result["structuredContent"] = structured
        NexusTransportFixture.configure(result: result)
        await failure { try await self.submit() }
        XCTAssertEqual(NexusTransportFixture.requests.filter { $0.method == "tools/call" }.count, 1)
    }
    func testUnavailableNetworkCannotOpenTheSubmissionTransport() async {
        await failure { try await self.transport.submit(signedNorito: Data([1]), idempotencyKey: UUID(), expectedHash: self.txHash, configuration: .minamoto) }
        XCTAssertTrue(NexusTransportFixture.requests.isEmpty)
    }
    func testAllToriiErrorsHaveActionableNonemptyDescriptions() {
        let errors: [NexusToriiError] = [.invalidRoute, .invalidResponse, .mcpContractMismatch, .mcpNotEnabled, .deploymentUnavailable, .responseTooLarge, .httpStatus(503), .server, .transactionHashMismatch, .ambiguousSubmission, .confirmationAlreadySubmitted, .nativeBridgeUnavailable, .finalizedHeadUnavailable, .sendsDisabled, .wrongWalletOrNetwork, .quoteChanged, .quoteExpired, .insufficientBalance]
        let descriptions = errors.compactMap(\.errorDescription)
        XCTAssertEqual(descriptions.count, errors.count); XCTAssertEqual(Set(descriptions).count, errors.count)
        XCTAssertTrue(descriptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(NexusToriiError.httpStatus(503).localizedDescription.contains("503"))
        XCTAssertTrue(NexusToriiError.ambiguousSubmission.localizedDescription.contains("not retried"))
        XCTAssertTrue(NexusToriiError.quoteExpired.localizedDescription.contains("Review"))
    }
}

private final class NexusTransportFixture: URLProtocol {
    struct Recorded {
        let method: String; let tool: String?; let arguments: [String: Any]?
        let timeout: TimeInterval; let url: URL?; let httpMethod: String?; let protocolVersion: String?; let contentType: String?; let accept: String?
    }
    private static let lock = NSLock()
    private static var recorded: [Recorded] = []
    private static var callResult: Any = [:]
    static var discoveryPages: [[String: Any]] = []
    static var discoveryResult: [String: Any]?
    static var responseID: String?
    static var rpcError: [String: Any]?
    static var statusCode = 200
    static var contentType = "application/json"
    static var extraHeaders: [String: String] = [:]
    private static let version = String(repeating: "f", count: 64)
    static var requests: [Recorded] { lock.lock(); defer { lock.unlock() }; return recorded }
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        recorded = []; callResult = [:]; discoveryPages = []; discoveryResult = nil
        responseID = nil; rpcError = nil; statusCode = 200; contentType = "application/json"; extraHeaders = [:]
    }
    static func configure(result: Any) { lock.lock(); callResult = result; lock.unlock() }
    static var descriptors: [[String: Any]] {
        func scalar(_ type: String) -> [String: Any] { ["type": type] }
        func path(_ key: String) -> [String: Any] { ["type": "object", "properties": [key: scalar("string")], "required": [key]] }
        let schemas: [(String, [String: Any])] = [
            ("iroha.health", [:]),
            ("iroha.transactions.submit_and_wait", ["body_base64": scalar("string"), "hash": scalar("string"), "status_accept": scalar("string"), "timeout_ms": scalar("integer")]),
            ("iroha.assets.definitions.get", ["path": path("definition_id"), "accept": scalar("string")]),
            ("iroha.accounts.assets", ["path": path("account_id"), "filter": scalar("string"), "limit": scalar("integer"), "include_total": scalar("boolean"), "accept": scalar("string")]),
            ("iroha.transactions.status", ["query": path("hash"), "accept": scalar("string")]),
            ("iroha.accounts.history", ["path": path("account_id"), "filter": scalar("string"), "limit": scalar("integer"), "cursor": scalar("string"), "accept": scalar("string")])]
        return schemas.map { name, properties in ["name": name, "inputSchema": ["type": "object", "properties": properties, "required": name == "iroha.transactions.submit_and_wait" ? ["body_base64"] : []], "outputSchema": ["type": "object"]] }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; body.append(contentsOf: bytes.prefix(count)) }
            }
            let envelope = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let method = envelope["method"] as! String
            let params = envelope["params"] as? [String: Any] ?? [:]
            Self.lock.lock()
            Self.recorded.append(Recorded(method: method, tool: params["name"] as? String, arguments: params["arguments"] as? [String: Any],
                timeout: request.timeoutInterval, url: request.url, httpMethod: request.httpMethod, protocolVersion: request.value(forHTTPHeaderField: "MCP-Protocol-Version"),
                contentType: request.value(forHTTPHeaderField: "Content-Type"), accept: request.value(forHTTPHeaderField: "Accept")))
            let result: Any
            switch method {
            case "server/discover": result = Self.discoveryResult ?? ["supportedVersions": ["2026-07-28"], "capabilities": ["extensions": ["org.hyperledger.iroha/tools": ["toolsetVersion": Self.version]]]]
            case "tools/list":
                let pageIndex = Self.recorded.filter { $0.method == "tools/list" }.count - 1
                var page = Self.discoveryPages.isEmpty ? ["tools": Self.descriptors] : Self.discoveryPages[min(pageIndex, Self.discoveryPages.count - 1)]
                page["_meta"] = ["iroha": ["listChanged": false, "toolsetVersion": Self.version]]
                result = page
            default: result = Self.callResult
            }
            var response: [String: Any] = ["jsonrpc": "2.0", "id": Self.responseID ?? (envelope["id"] as? String ?? ""), "result": result]
            if let error = Self.rpcError { response.removeValue(forKey: "result"); response["error"] = error }
            let code = Self.statusCode
            var headers = Self.extraHeaders; headers["Content-Type"] = Self.contentType
            Self.lock.unlock()
            let responseBody = try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])
            let http = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseBody)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
