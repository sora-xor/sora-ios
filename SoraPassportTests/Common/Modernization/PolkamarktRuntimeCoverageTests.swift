// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import SoraPassport

/// Exercise the actual bounded HTTP/JSON-RPC client against an in-memory node.
/// URLProtocol intercepts every request; none reaches a live chain or signer.
final class PolkamarktRuntimeCoverageTests: XCTestCase {
    private var session: URLSession!
    private var rpc: PolkamarktRPCClient!
    private let checkpointHash = "0x" + String(repeating: "ab", count: 32)

    override func setUp() {
        super.setUp()
        MarketRPCFixture.reset([:])
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MarketRPCFixture.self]
        session = URLSession(configuration: config)
        rpc = PolkamarktRPCClient(engine: Sora2BoundedHTTPJSONRPCEngine(
            nodeURL: URL(string: "https://polkamarkt.test")!, session: session))
    }
    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        rpc = nil
        super.tearDown()
    }
    private func encoded(_ value: String) -> String {
        String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }
    private func header(_ number: String) -> String {
        let root = "0x" + String(repeating: "00", count: 32)
        return #"{"parentHash":"\#(checkpointHash)","number":"\#(number)","stateRoot":"\#(root)","extrinsicsRoot":"\#(root)","digest":{"logs":[]}}"#
    }
    private func block(_ number: String = "0xa", extrinsics: [String]) -> String {
        let body = String(data: try! JSONEncoder().encode(extrinsics), encoding: .utf8)!
        return #"{"block":{"header":\#(header(number)),"extrinsics":\#(body)}}"#
    }
    private func expectFailure<T>(file: StaticString = #filePath, line: UInt = #line,
                                  _ operation: () async throws -> T) async {
        do { _ = try await operation(); XCTFail("Malformed or unavailable RPC data was accepted", file: file, line: line) }
        catch { }
    }
    private func assertParams(_ method: String, _ expected: [Any], file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = try XCTUnwrap(MarketRPCFixture.parameters(method), file: file, line: line)
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys]),
                       try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]), file: file, line: line)
    }

    func testFinalizedHeadUsesTheHeadMethod() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getHead: encoded(checkpointHash)])
        let head = try await rpc.finalizedHead()
        XCTAssertEqual(head, checkpointHash)
        XCTAssertEqual(MarketRPCFixture.methods, [SoraPassport.RPCMethod.getHead])
    }

    func testReviewedGenesisRequiresThePinnedMainnet() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: encoded(PIIndexerClient.soraMainnetGenesis)])
        let genesis = try await rpc.reviewedGenesisHash()
        XCTAssertEqual(genesis, PIIndexerClient.soraMainnetGenesis)
        try assertParams(SoraPassport.RPCMethod.getBlockHash, [0])
    }

    func testUnknownWrongAndNoncanonicalGenesisAreRejected() async {
        for result in ["null", encoded(checkpointHash), encoded(PIIndexerClient.soraMainnetGenesis.uppercased())] {
            MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: result])
            await expectFailure { try await self.rpc.reviewedGenesisHash() }
        }
    }

    func testNegativeBlockHeightNeverReachesTransport() async throws {
        let value = try await rpc.blockHash(at: -1)
        XCTAssertNil(value)
        XCTAssertTrue(MarketRPCFixture.methods.isEmpty)
    }

    func testBlockHashIsCanonicalizedAndMissingOrInvalidHashIsAbsent() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: encoded("0x" + String(repeating: "AB", count: 32))])
        let value = try await rpc.blockHash(at: 10)
        XCTAssertEqual(value, String(repeating: "ab", count: 32))
        try assertParams(SoraPassport.RPCMethod.getBlockHash, [10])
        for result in ["null", encoded("0x1234"), encoded("unexpected")] {
            MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: result])
            let missing = try await rpc.blockHash(at: 10)
            XCTAssertNil(missing)
        }
    }

    func testFinalizedHeightUsesTheHeaderOfThatExactHead() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getHead: encoded(checkpointHash), SoraPassport.RPCMethod.getHeader: header("0x1f")])
        let height = try await rpc.finalizedBlockNumber()
        XCTAssertEqual(height, BigUInt(31))
        try assertParams(SoraPassport.RPCMethod.getHeader, [checkpointHash])
    }

    func testFinalizedHeightRejectsNonHexAndOversizedNumbers() async {
        for value in ["31", "0x", "0x-1", "0xg1", "0x" + String(repeating: "a", count: 65)] {
            MarketRPCFixture.reset([SoraPassport.RPCMethod.getHead: encoded(checkpointHash), SoraPassport.RPCMethod.getHeader: header(value)])
            await expectFailure { try await self.rpc.finalizedBlockNumber() }
        }
    }

    func testCanonicalExtrinsicLookupDoesNotQueryFutureOrNegativeBlocks() async throws {
        let negative = try await rpc.canonicalExtrinsicHashes(at: -1, notAfter: 10)
        let future = try await rpc.canonicalExtrinsicHashes(at: 11, notAfter: 10)
        XCTAssertNil(negative)
        XCTAssertNil(future)
        XCTAssertTrue(MarketRPCFixture.methods.isEmpty)
    }

    func testCanonicalExtrinsicsPreserveExactBlockAndIndices() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: encoded(checkpointHash), SoraPassport.RPCMethod.getChainBlock: block(extrinsics: ["0x00", "0x0102"])])
        let result = try await rpc.canonicalExtrinsicHashes(at: 10, notAfter: 11)
        let canonical = try XCTUnwrap(result)
        XCTAssertEqual(canonical.blockHash, String(checkpointHash.dropFirst(2)))
        XCTAssertEqual(canonical.extrinsicIndices, [
            "03170a2e7597b7b7e3d84c05391d139a62b157e78786d8c082f29dcf4c111314": 0,
            "65da3986eaecf046cb2c41673aed9d4e1e661730dc31c62f327df5d15933595d": 1
        ])
        try assertParams(SoraPassport.RPCMethod.getChainBlock, [checkpointHash])
    }

    func testCanonicalExtrinsicsRejectWrongHeaderHeight() async {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: encoded(checkpointHash), SoraPassport.RPCMethod.getChainBlock: block("0xb", extrinsics: ["0x00"])])
        await expectFailure { try await self.rpc.canonicalExtrinsicHashes(at: 10, notAfter: 11) }
    }

    func testDuplicateExtrinsicHashesCannotOverwriteAnEarlierIndex() async {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: encoded(checkpointHash), SoraPassport.RPCMethod.getChainBlock: block(extrinsics: ["0x00", "0x00"])])
        await expectFailure { try await self.rpc.canonicalExtrinsicHashes(at: 10, notAfter: 10) }
    }

    func testMalformedExtrinsicBytesAreNotAcceptedAsCanonicalEvidence() async {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: encoded(checkpointHash), SoraPassport.RPCMethod.getChainBlock: block(extrinsics: ["0xnothex"])])
        await expectFailure { try await self.rpc.canonicalExtrinsicHashes(at: 10, notAfter: 10) }
    }

    func testMissingCanonicalBlockStopsBeforeFetchingItsBody() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getBlockHash: "null"])
        let result = try await rpc.canonicalExtrinsicHashes(at: 10, notAfter: 10)
        XCTAssertNil(result)
        XCTAssertEqual(MarketRPCFixture.methods, [SoraPassport.RPCMethod.getBlockHash])
    }

    func testMetadataAndVersionRequestsRemainBoundToTheirCheckpoint() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.getRuntimeMetadata: encoded("0x0102"), SoraPassport.RPCMethod.getRuntimeVersion: #"{"specVersion":130,"transactionVersion":130}"#])
        let latest = try await rpc.metadataHex()
        XCTAssertEqual(latest, "0x0102")
        let specific = try await rpc.metadataHex(at: checkpointHash)
        XCTAssertEqual(specific, "0x0102")
        try assertParams(SoraPassport.RPCMethod.getRuntimeMetadata, [checkpointHash])
        let version = try await rpc.runtimeVersion(at: checkpointHash)
        XCTAssertEqual(version.specVersion, 130)
        XCTAssertEqual(version.transactionVersion, 130)
        try assertParams(SoraPassport.RPCMethod.getRuntimeVersion, [checkpointHash])
    }

    func testBuyQuotePreservesTheExactLargeIntegerAndRuntimeParameters() async throws {
        MarketRPCFixture.reset([PolkamarktRuntimeContract.RPC.quoteBuy: #"{"marketId":42,"outcome":"Yes","collateralIn":"12000000000000000001","feeAmount":"1","pricingCollateral":"12000000000000000000","sharesOut":"24000000000000000000"}"#])
        let exact = BigUInt("12000000000000000001", radix: 10)!
        let result = try await rpc.quoteBuy(marketId: 42, outcome: .yes, collateralIn: exact, at: checkpointHash)
        let quote = try XCTUnwrap(result)
        XCTAssertEqual(quote.collateralIn, exact)
        XCTAssertEqual(quote.sharesOut, BigUInt("24000000000000000000"))
        try assertParams(PolkamarktRuntimeContract.RPC.quoteBuy, [42, "Yes", exact.description, checkpointHash])
    }

    func testSellQuotePreservesSharePrecisionAndOppositeOutcome() async throws {
        MarketRPCFixture.reset([PolkamarktRuntimeContract.RPC.quoteSell: #"{"marketId":42,"outcome":"No","sharesIn":"99999999999999999999","grossCollateralOut":"50","feeAmount":"1","collateralOut":"49"}"#])
        let exact = BigUInt("99999999999999999999", radix: 10)!
        let result = try await rpc.quoteSell(marketId: 42, outcome: .no, sharesIn: exact, at: checkpointHash)
        let quote = try XCTUnwrap(result)
        XCTAssertEqual(quote.sharesIn, exact)
        XCTAssertEqual(quote.collateralOut, 49)
        try assertParams(PolkamarktRuntimeContract.RPC.quoteSell, [42, "No", exact.description, checkpointHash])
    }

    func testUnavailableQuotesAreNilInsteadOfInventedZeroQuotes() async throws {
        MarketRPCFixture.reset([PolkamarktRuntimeContract.RPC.quoteBuy: "null", PolkamarktRuntimeContract.RPC.quoteSell: "null"])
        let buy = try await rpc.quoteBuy(marketId: 42, outcome: .yes, collateralIn: 1, at: checkpointHash)
        let sell = try await rpc.quoteSell(marketId: 42, outcome: .no, sharesIn: 1, at: checkpointHash)
        XCTAssertNil(buy)
        XCTAssertNil(sell)
    }

    func testMarketStateDecodesExactAmountsWithoutInventingFinalizedStatus() async throws {
        MarketRPCFixture.reset([PolkamarktRuntimeContract.RPC.marketState: #"{"marketId":42,"mechanism":"DynamicParimutuel","virtualDepth":"99999999999999999999","realYesShares":"10","realNoShares":"20","dpmCollateral":"30","marginalYesPriceBps":6000,"marginalNoPriceBps":4000,"impliedYesProbabilityBps":6000,"impliedNoProbabilityBps":4000}"#])
        let result = try await rpc.marketState(marketId: 42, at: checkpointHash)
        let state = try XCTUnwrap(result)
        XCTAssertEqual(state.virtualDepth, BigUInt("99999999999999999999"))
        XCTAssertNil(state.finalizedStatus)
        try assertParams(PolkamarktRuntimeContract.RPC.marketState, [42, checkpointHash])
    }

    func testClaimableValuesRemainAccountMarketAndCheckpointBound() async throws {
        MarketRPCFixture.reset([PolkamarktRuntimeContract.RPC.claimable: #"{"marketId":42,"account":"owner","status":"Resolved","resolutionOutcome":"Yes","yesShares":"10","noShares":"20","netCollateralPaid":"30","traderPayout":"40","claimablePayout":"40","creatorFees":"1","isCreator":true}"#])
        let result = try await rpc.claimable(account: "owner", marketId: 42, at: checkpointHash)
        let claim = try XCTUnwrap(result)
        XCTAssertEqual(claim.account, "owner")
        XCTAssertEqual(claim.claimablePayout, 40)
        XCTAssertEqual(claim.creatorFees, 1)
        XCTAssertTrue(claim.isCreator)
        try assertParams(PolkamarktRuntimeContract.RPC.claimable, ["owner", 42, checkpointHash])
    }

    func testFreeBalanceIsExactAndAnAbsentAccountHasZeroBalance() async throws {
        MarketRPCFixture.reset([SoraPassport.RPCMethod.freeBalance: #"{"balance":"999999999999999999999999999999"}"#])
        let value = try await rpc.freeBalance(account: "owner", assetId: "xor", at: checkpointHash)
        XCTAssertEqual(value, BigUInt("999999999999999999999999999999"))
        try assertParams(SoraPassport.RPCMethod.freeBalance, ["owner", "xor", checkpointHash])
        MarketRPCFixture.reset([SoraPassport.RPCMethod.freeBalance: "null"])
        let absent = try await rpc.freeBalance(account: "missing", assetId: "xor", at: checkpointHash)
        XCTAssertEqual(absent, 0)
    }

    func testRPCAndDecodingFailuresPropagateInsteadOfCreatingBalances() async {
        // Missing methods receive a real JSON-RPC error from this fixture.
        await expectFailure { try await self.rpc.freeBalance(account: "owner", assetId: "xor", at: self.checkpointHash) }
        MarketRPCFixture.reset([SoraPassport.RPCMethod.freeBalance: #"{"balance":"not-a-number"}"#])
        await expectFailure { try await self.rpc.freeBalance(account: "owner", assetId: "xor", at: self.checkpointHash) }
    }
}

private final class MarketRPCFixture: URLProtocol {
    private static let lock = NSLock()
    private static var answers: [String: String] = [:]
    private static var requests: [(String, [Any])] = []
    static func reset(_ answers: [String: String]) {
        lock.lock(); defer { lock.unlock() }
        self.answers = answers; requests = []
    }
    static var methods: [String] {
        lock.lock(); defer { lock.unlock() }
        return requests.map { $0.0 }
    }
    static func parameters(_ method: String) -> [Any]? {
        lock.lock(); defer { lock.unlock() }
        return requests.last { $0.0 == method }?.1
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count <= 0 { break }
                    body.append(bytes, count: count)
                }
            }
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let method = try XCTUnwrap(object["method"] as? String)
            let identifier = try XCTUnwrap(object["id"] as? Int)
            Self.lock.lock()
            Self.requests.append((method, object["params"] as? [Any] ?? []))
            let answer = Self.answers[method]
            Self.lock.unlock()
            let text = answer.map { #"{"jsonrpc":"2.0","id":\#(identifier),"result":\#($0)}"# }
                ?? #"{"jsonrpc":"2.0","id":\#(identifier),"error":{"code":-32601,"message":"Method not found"}}"#
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(text.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
