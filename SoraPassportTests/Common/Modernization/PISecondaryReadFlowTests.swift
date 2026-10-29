// SPDX-License-Identifier: Apache-2.0
import Foundation
import SoraKeystore
import XCTest
import sorawallet
@testable import SoraPassport

@MainActor
final class PISecondaryReadFlowTests: XCTestCase {
    private var session: URLSession!, client: PIIndexerClient!, directory: URL!
    private let server = SecondaryReadServer()
    override func setUp() {
        super.setUp(); server.reset(); PIStubIndexerProtocol.install { [server] in server.respond($0) }
        session = PIStubIndexerProtocol.session(); directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        client = PIIndexerClient(session: session, historyShapeMemory: PIHistoryShapeMemory(), cacheDirectory: directory, retryPause: { _ in })
    }
    override func tearDown() { session.invalidateAndCancel(); PIStubIndexerProtocol.uninstall(); try? FileManager.default.removeItem(at: directory); client = nil; super.tearDown() }
    private func equal<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(a,b,file:file,line:line) }
    private func rejects(_ block: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await block(); XCTFail("Invalid indexed data was accepted",file:file,line:line) } catch {}
    }
    func testPoolPagePreservesExactReservesAndPrices() async throws { let p = try await client.poolXYKs(); equal(p.values.first?.baseAssetReserves?.rawValue,"123456789012345678901234567890"); equal(p.values.first?.poolTokenPriceUSD?.rawValue,"0.123456789012345678") }
    func testWholePoolCatalogFollowsEveryCursor() async throws { server.twoPages = true; equal(try await client.allPoolXYKs(pageSize: 1).map(\.id),["pool-1","pool-2"]); equal(server.requests.filter{$0.operation == "MobilePoolXYKs"}.count,2) }
    func testQualifiedPoolCatalogKeepsLiveCheckpoint() async throws { let read = try await client.qualifiedAllPoolXYKs(); equal(read.qualification?.source,.live); equal(read.value.count,1) }
    func testPoolCatalogFallsBackOnlyAfterACompleteGoodRead() async throws { _ = try await client.allPoolXYKs(); server.status = 503; let read = try await client.qualifiedAllPoolXYKs(); equal(read.qualification?.source,.cache); equal(read.value.map(\.id),["pool-1"]) }
    func testMalformedPoolPageDoesNotBecomeAnOfflineSuccess() async throws { _ = try await client.allPoolXYKs(); server.override = ["baseAssetReserves":"-1"]; await rejects { _ = try await self.client.qualifiedAllPoolXYKs() } }
    func testPoolCatalogPageBoundDoesNotReturnAPartialCatalog() async { server.twoPages = true; await rejects { _ = try await self.client.allPoolXYKs(pageSize: 1,maximumPages: 1) } }
    func testPoolPageRejectsZeroPageSizeBeforeAnyRequest() async { await rejects { _ = try await self.client.poolXYKs(first: 0) }; equal(server.requests.count,0) }
    func testPoolPageRejectsOversizedCursorBeforeAnyRequest() async { await rejects { _ = try await self.client.poolXYKs(after: String(repeating:"x",count:4097)) }; equal(server.requests.count,0) }
    func testPoolCatalogRejectsRepeatedIdentityAcrossPages() async { server.twoPages = true; server.repeatID = true; await rejects { _ = try await self.client.allPoolXYKs(pageSize: 1) } }
    func testEmptyPoolCatalogIsACompleteLiveRead() async throws { server.empty = true; equal(try await client.allPoolXYKs().count,0) }

    func testPositionsAreBoundToRequestedAccountAndMarket() async throws { let page = try await client.accountPositions(account:"wallet-a"); equal(page.values.first?.account,"wallet-a"); equal(page.values.first?.market?.marketId,42); equal(page.values.first?.shares?.rawValue,"12.000000000000000001"); equal(server.requests.last(where: { $0.operation == "MobilePolkamarktPositions" })?.variables["filter"] as? [String:[String:String]],["account":["equalTo":"wallet-a"]]) }
    func testAllPositionsWalksPagesInOrder() async throws { server.twoPages = true; equal(try await client.allAccountPositions(account:"wallet-a",pageSize:1).map(\.id),["position-1","position-2"]) }
    func testQualifiedPositionsCarryTheFinalizedRead() async throws { let read = try await client.qualifiedAllAccountPositions(account:"wallet-a"); equal(read.qualification?.source,.live); equal(read.value.count,1) }
    func testPositionsRejectAnotherAccount() async { server.override = ["account":"wallet-b"]; await rejects { _ = try await self.client.accountPositions(account:"wallet-a") } }
    func testPositionsRejectMismatchedNestedMarket() async { server.override = ["marketId":43]; await rejects { _ = try await self.client.accountPositions(account:"wallet-a") } }
    func testPositionsRejectNegativeShareBalances() async { server.override = ["yesShares":"-1"]; await rejects { _ = try await self.client.accountPositions(account:"wallet-a") } }
    func testPositionsRejectAFutureMarketCheckpoint() async { server.marketHeight = 2000; await rejects { _ = try await self.client.accountPositions(account:"wallet-a") } }
    func testPositionsRejectAbsentNestedMarket() async { server.override = ["market":NSNull()]; await rejects { _ = try await self.client.accountPositions(account:"wallet-a") } }
    func testPositionPageRejectsAnEmptyAccountBeforeAnyRequest() async { await rejects { _ = try await self.client.accountPositions(account:"") }; equal(server.requests.count,0) }
    func testPositionsRejectDuplicateRowsAcrossPages() async { server.twoPages = true; server.repeatID = true; await rejects { _ = try await self.client.allAccountPositions(account:"wallet-a",pageSize:1) } }
    func testPositionsAllowAnExactNegativePnlWithoutChangingItsSign() async throws { let p = try await client.accountPositions(account:"wallet-a"); equal(p.values.first?.realizedPnlUsd?.rawValue,"-0.000000000000000001") }

    func testTradesPreserveHashAmountsAndBatchMarketIdentity() async throws { let page = try await client.accountTrades(account:"wallet-a"); let t = try XCTUnwrap(page.values.first); equal(t.extrinsicHash,server.hash); equal(t.sharesOut?.rawValue,"9007199254740993"); XCTAssertTrue(t.includesMarket(42)); XCTAssertTrue(t.includesMarket(43)); XCTAssertFalse(t.includesMarket(44)) }
    func testAllTradesWalksEveryPage() async throws { server.twoPages = true; equal(try await client.allAccountTrades(account:"wallet-a",pageSize:1).map(\.id),["trade-1","trade-2"]) }
    func testQualifiedTradesPreserveLiveQualification() async throws { let read = try await client.qualifiedAllAccountTrades(account:"wallet-a"); equal(read.qualification?.source,.live); equal(read.value.count,1) }
    func testTradesRejectAnotherAccount() async { server.override = ["account":"wallet-b"]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectMalformedExtrinsicHash() async { server.override = ["extrinsicHash":"0x01"]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectMalformedBlockHash() async { server.override = ["blockHash":"0x01"]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectNegativeExecutionPrice() async { server.override = ["executionPrice":"-1"]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectFutureInclusionHeight() async { server.override = ["blockNumber":2000]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectDuplicateBatchMarketIds() async { server.override = ["marketIds":[42,42]]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectBatchPrimaryMarketMismatch() async { server.override = ["marketIds":[43,42]]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradesRejectMissingInclusionHeight() async { server.override = ["blockNumber":NSNull()]; await rejects { _ = try await self.client.accountTrades(account:"wallet-a") } }
    func testTradeWalkRejectsPaginationExhaustion() async { server.twoPages = true; await rejects { _ = try await self.client.allAccountTrades(account:"wallet-a",pageSize:1,maximumPages:1) } }

    func testPendingLookupReturnsOnlyItsBoundedRequestedSet() async throws { let read = try await client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[server.hash]); equal(read.value.map(\.id),[server.hash]); equal(read.qualification?.source,.live) }
    func testPendingLookupAllowsTheRequestedAccountAsRecipient() async throws { server.override = ["address":"wallet-b","dataFrom":"wallet-b","dataTo":"wallet-a"]; equal(try await client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[server.hash]).value.count,1) }
    func testPendingLookupRejectsAnUnrequestedHash() async { server.override = ["id":server.otherHash]; await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[self.server.hash]) } }
    func testPendingLookupRejectsAnUnrelatedAccount() async { server.override = ["address":"wallet-b","dataFrom":"wallet-b","dataTo":"wallet-c"]; await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[self.server.hash]) } }
    func testPendingLookupAcceptsAnEmptyCompleteResponse() async throws { server.empty = true; equal(try await client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[server.hash]).value.count,0) }
    func testPendingLookupRejectsAResponseWithMorePages() async { server.twoPages = true; await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[self.server.hash]) } }
    func testPendingLookupRejectsEmptyHashListBeforeNetwork() async { await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[]) }; equal(server.requests.count,0) }
    func testPendingLookupRejectsMalformedHashBeforeNetwork() async { await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:["0x01"]) }; equal(server.requests.count,0) }
    func testPendingLookupRejectsCaseOnlyDuplicateHashesBeforeNetwork() async { await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:[self.server.hash,self.server.hash.uppercased()]) }; equal(server.requests.count,0) }
    func testPendingLookupRejectsSurroundingAccountWhitespaceBeforeNetwork() async { await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:" wallet-a",transactionHashes:[self.server.hash]) }; equal(server.requests.count,0) }
    func testPendingLookupRejectsOverBoundedHashSetBeforeNetwork() async { let hashes = (0...100).map { "0x" + String(format:"%064x",$0) }; await rejects { _ = try await self.client.qualifiedHistoryByTransactionHashes(address:"wallet-a",transactionHashes:hashes) }; equal(server.requests.count,0) }
    func testWholeHistoryWalkIncludesEveryDistinctTransaction() async throws {
        server.twoPages = true
        equal(try await client.allHistory(address: "wallet-a", pageSize: 1).map(\.id), [server.hash, server.otherHash])
        equal(server.requests.filter { $0.operation == "MobileHistory" }.compactMap { $0.variables["after"] as? String }, ["c1"])
    }
    func testQualifiedWholeHistoryRetainsItsLiveCheckpoint() async throws {
        let read = try await client.qualifiedAllHistory(address: "wallet-a")
        equal(read.value.map(\.id), [server.hash]); equal(read.qualification?.source, .live)
    }
    func testWholeHistoryAllowsAnAuthoritativeEmptyAccount() async throws {
        server.empty = true; equal(try await client.allHistory(address: "wallet-a").count, 0)
    }
    func testWholeHistoryRejectsPartialResultsAtThePageLimit() async {
        server.twoPages = true
        await rejects { _ = try await self.client.allHistory(address: "wallet-a", pageSize: 1, maximumPages: 1) }
    }
    func testWholeHistoryRejectsRepeatedTransactionAcrossPages() async {
        server.twoPages = true; server.repeatID = true
        await rejects { _ = try await self.client.qualifiedAllHistory(address: "wallet-a", pageSize: 1) }
    }
    func testHistoryPageAdapterWalksToTheRequestedPage() async throws {
        server.twoPages = true
        let read = try await client.qualifiedHistoryPage(address: "wallet-a", first: 1, page: 2)
        equal(read.value.values.map(\.id), [server.otherHash]); equal(read.value.totalCount, 2)
        equal(read.qualification?.source, .live)
    }
    func testHistoryPageBeyondTheEndIsEmptyWithTheAuthoritativeTotal() async throws {
        let read = try await client.qualifiedHistoryPage(address: "wallet-a", first: 1, page: 3)
        equal(read.value.values.count, 0); equal(read.value.totalCount, 1)
        XCTAssertFalse(read.value.pageInfo.hasNextPage); XCTAssertTrue(read.value.pageInfo.hasPreviousPage)
        XCTAssertNil(read.value.pageInfo.endCursor); equal(read.qualification?.source, .live)
        equal(server.requests.filter { $0.operation == "MobileHistory" }.count, 1)
    }
    func testHistoryPagePastAnEmptyAccountDoesNotInventPagination() async throws {
        server.empty = true
        let read = try await client.qualifiedHistoryPage(address: "wallet-a", first: 1, page: 2)
        equal(read.value.totalCount, 0); XCTAssertTrue(read.value.values.isEmpty); XCTAssertFalse(read.value.pageInfo.hasNextPage)
    }
    func testHistoryNumberedPageRejectsInvalidBoundsBeforeNetwork() async {
        for page in [0, -1, 4] {
            await rejects { _ = try await self.client.qualifiedHistoryPage(address: "wallet-a", first: 1, page: page, maximumPages: 3) }
        }
        equal(server.requests.count, 0)
    }
    func testWholeHistoryFailureDoesNotBecomeAnEmptyHistory() async {
        server.status = 503
        await rejects { _ = try await self.client.allHistory(address: "wallet-a") }
    }
    func testDirectHistoryPagePreservesTransactionAndAccountIdentity() async throws {
        let read = try await client.history(address: "wallet-a", first: 1)
        equal(read.values.map(\.id), [server.hash]); equal(read.values.first?.address, "wallet-a")
    }
    func testQualifiedDirectHistoryPageRetainsLiveProvenance() async throws {
        let read = try await client.qualifiedHistory(address: "wallet-a", first: 1)
        equal(read.qualification?.source, .live); equal(read.value.values.map(\.id), [server.hash])
    }
    func testReferrerRewardPagePreservesExactAmountAndFilter() async throws {
        let page = try await client.referrerRewards(address: "wallet-a", first: 1)
        equal(page.values.first?.amount?.rawValue, "123456789012345678901")
        equal(page.values.first?.referrer, "wallet-a")
        equal(server.requests.last(where: { $0.operation == "MobileReferrerRewards" })?.variables["filter"] as? [String: [String: String]], ["referrer": ["equalTo": "wallet-a"]])
    }
}

private final class SecondaryReadServer {
    let hash = "0x" + String(repeating:"ab",count:32), otherHash = "0x" + String(repeating:"cd",count:32)
    var override = [String:Any](), twoPages = false, repeatID = false, empty = false, status = 200, marketHeight = 900
    private let lock = NSLock(); private var recorded = [PIStubIndexerProtocol.Request]()
    var requests: [PIStubIndexerProtocol.Request] { lock.lock(); defer { lock.unlock() }; return recorded }
    func reset() { override = [:]; twoPages = false; repeatID = false; empty = false; status = 200; marketHeight = 900; lock.lock(); recorded = []; lock.unlock() }
    func respond(_ request: PIStubIndexerProtocol.Request) -> PIStubIndexerProtocol.Response {
        lock.lock(); recorded.append(request); lock.unlock()
        if request.operation == "MobileHealth" { return .init(body:PIAdvancingIndexer.health(indexed:1000,finalized:1001,indexedAt:Int(Date().timeIntervalSince1970)-1)) }
        if status != 200 { return .init(status:status,body:"{}") }
        if request.operation == "MobilePolkamarktSignals" {
            let signals: [String: Any] = ["totalVolumeUsd": "123.000000000000000001", "activeMarkets": 2, "activeAccounts": 3, "liquidityUsd": "50", "liquiditySeries": [["label": "2026-01", "value": "25"]], "answerBreakdown": [["answer": "Yes", "volumeUsd": "100", "markets": 2]], "accuracySummary": ["accuracyPercent": 75]]
            let data = try! JSONSerialization.data(withJSONObject: ["data": ["polkamarktSignals": signals.merging(override) { _, new in new }]])
            return .init(body: String(data: data, encoding: .utf8)!)
        }
        let prior = request.variables["after"] as? String != nil, index = prior && !repeatID ? 2 : 1
        let market: [String:Any] = ["id":"market-42","marketId":42,"status":"Open","updatedAtBlock":marketHeight,"timestamp":100]
        let name: String; let row: [String:Any]
        switch request.operation {
        case "MobileAssets": name = "assets"; row = ["id": WalletAssetId.xor.rawValue, "symbol": "XOR", "name": "SORA", "decimals": 18, "priceUSD": "1.000000000000000001"]
        case "MobilePolkamarktMarkets": name = "markets"; row = ["id": "market-\(index)", "marketId": 41 + index, "status": "Open", "updatedAtBlock": marketHeight, "timestamp": 100, "priceYes": "0.123456789012345678"]
        case "MobilePolkamarktSnapshots": name = "marketSnapshots"; row = ["id": "snapshot-\(index)", "marketId": 42, "timestamp": 100 * index, "blockHeight": 900, "type": "DEFAULT", "priceYes": "0.25"]
        case "MobilePoolXYKs": name = "poolXYKs"; row = ["id":"pool-\(index)","baseAssetId":WalletAssetId.xor.rawValue,"targetAssetId":WalletAssetId.val.rawValue,"baseAssetReserves":"123456789012345678901234567890","targetAssetReserves":"2000","priceUSD":"2.5","poolTokenSupply":"3000","poolTokenPriceUSD":"0.123456789012345678","liquidityUSD":"100"]
        case "MobilePolkamarktPositions": name = "accountPositions"; row = ["id":"position-\(index)","account":"wallet-a","marketId":42,"market":market,"shares":"12.000000000000000001","yesShares":"12","noShares":"0","realizedPnlUsd":"-0.000000000000000001"]
        case "MobilePolkamarktTrades": name = "accountTrades"; row = ["id":"trade-\(index)","account":"wallet-a","marketId":42,"marketIds":[42,43],"market":market,"side":"buy","outcome":"Yes","sharesOut":"9007199254740993","executionPrice":"0.25","blockNumber":900,"blockHash":otherHash,"extrinsicHash":hash]
        case "MobileReferrerRewards": name = "referrerRewards"; row = ["id":"reward-\(index)","referrer":"wallet-a","referral":"wallet-b","timestamp":100,"blockHeight":"900","amount":"123456789012345678901"]
        case "MobileHistory": name = "historyElements"; row = ["id":index == 1 ? hash : otherHash,"address":"wallet-a","dataFrom":"wallet-a","dataTo":"wallet-b","timestamp":100,"blockHeight":900,"blockHash":otherHash,"networkFee":"7","execution":["success":true]]
        default: return .init(status:400,body:"{}")
        }
        let rows = empty ? [] : [row.merging(override){_,new in new}]
        let page: [String:Any] = ["nodes":rows,"pageInfo":["hasNextPage":twoPages && !prior,"hasPreviousPage":prior,"startCursor":"c\(index)","endCursor":"c\(index)"],"totalCount":empty ? 0 : twoPages ? 2 : 1]
        let data = try! JSONSerialization.data(withJSONObject:["data":[name:page]])
        return .init(body:String(data:data,encoding:.utf8)!)
    }
}

extension PISecondaryReadFlowTests {
    func testIndexedExecutionBindsSuccessToTheExactCanonicalBlockAndHash() async throws {
        let read = try await Sora2PendingSubmissionReconciler.indexedExecutionFromPI(account: "wallet-a", transactionHash: server.hash, client: client)
        let r = try XCTUnwrap(read)
        equal(r.blockNumber, 900); equal(r.blockHash, String(server.otherHash.dropFirst(2))); XCTAssertTrue(r.succeeded)
    }
    func testIndexedExecutionPreservesAnExplicitDispatchFailure() async throws {
        server.override = ["execution": ["success": false]]
        let result = try await Sora2PendingSubmissionReconciler.indexedExecutionFromPI(account: "wallet-a", transactionHash: server.hash, client: client)
        XCTAssertEqual(result?.succeeded, false)
    }
    func testIndexedExecutionDoesNotInventOutcomeForAbsentTransactions() async throws {
        server.empty = true
        let result = try await Sora2PendingSubmissionReconciler.indexedExecutionFromPI(account: "wallet-a", transactionHash: server.hash, client: client)
        XCTAssertNil(result)
    }
    func testIndexedExecutionRejectsMalformedRequestedHashBeforeAnyLookup() async throws {
        let result = try await Sora2PendingSubmissionReconciler.indexedExecutionFromPI(account: "wallet-a", transactionHash: "0x01", client: client)
        XCTAssertNil(result); XCTAssertTrue(server.requests.isEmpty)
    }
    func testIndexedExecutionDoesNotInferSuccessWhenExecutionFlagIsAbsent() async throws {
        server.override = ["execution": NSNull()]
        do {
            _ = try await Sora2PendingSubmissionReconciler.indexedExecutionFromPI(account: "wallet-a", transactionHash: server.hash, client: client)
            XCTFail("An execution result without an explicit success flag cannot qualify as chain evidence")
        } catch {
            guard case PIIndexerError.invalidChainIdentity = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }
    func testIndexedExecutionDoesNotPromoteAnOfflineCachedHistoryRecordToFinality() async throws {
        _ = try await client.qualifiedHistoryByTransactionHashes(address: "wallet-a", transactionHashes: [server.hash])
        server.status = 503
        do {
            let result = try await Sora2PendingSubmissionReconciler.indexedExecutionFromPI(account: "wallet-a", transactionHash: server.hash, client: client)
            XCTAssertNil(result)
        } catch { XCTAssertTrue(server.requests.contains { $0.operation == "MobileHistory" }) }
    }
}

extension PISecondaryReadFlowTests {
    func testDirectAssetPageKeepsTheSmallestQuotedPriceUnit() async throws {
        let page = try await client.assets(first: 1)
        equal(page.values.first?.id, WalletAssetId.xor.rawValue)
        equal(page.values.first?.priceUSD?.rawValue, "1.000000000000000001")
    }
    func testMarketPagePreservesExactPriceAndRequestedStatusFilter() async throws {
        let page = try await client.markets(first: 1, status: .open)
        equal(page.values.first?.marketId, 42); equal(page.values.first?.priceYes?.rawValue, "0.123456789012345678")
        equal(server.requests.last(where: { $0.operation == "MobilePolkamarktMarkets" })?.variables["filter"] as? [String: [String: String]], ["status": ["equalTo": "Open"]])
    }
    func testCompleteMarketCatalogWalksAllPagesWithoutLosingRuntimeIdentity() async throws {
        server.twoPages = true
        equal(try await client.allMarkets(pageSize: 1).compactMap(\.marketId), [42, 43])
    }
    func testMarketStatusFilterRejectsAnOpenRowForAResolvedRequest() async {
        await rejects { _ = try await self.client.markets(status: .resolved) }
    }
    func testMarketCatalogRejectsARepeatedRuntimeIdEvenWhenRowIdsDiffer() async {
        server.twoPages = true; server.override = ["marketId": 42]
        await rejects { _ = try await self.client.allMarkets(pageSize: 1) }
    }
    func testMarketPageRejectsNegativePageSizeWithoutSendingRequest() async {
        await rejects { _ = try await self.client.markets(first: -1) }; equal(server.requests.count, 0)
    }
    func testCompleteMarketCatalogReturnsAnAuthoritativeEmptyList() async throws {
        server.empty = true; equal(try await client.allMarkets().count, 0)
    }
    func testMarketCatalogPaginationFailureDoesNotReturnTheFirstPageAsComplete() async {
        server.twoPages = true
        await rejects { _ = try await self.client.allMarkets(pageSize: 1, maximumPages: 1) }
    }
    func testSnapshotPageBindsTheChartToItsMarketAndCanonicalSeries() async throws {
        let page = try await client.marketSnapshots(marketId: 42, first: 1)
        equal(page.values.first?.marketId, 42); equal(page.values.first?.priceYes?.rawValue, "0.25")
        let filter = server.requests.last(where: { $0.operation == "MobilePolkamarktSnapshots" })?.variables["filter"] as? [String: [String: Any]]
        equal(filter?["marketId"]?["equalTo"] as? Int, 42); equal(filter?["type"]?["equalTo"] as? String, "DEFAULT")
    }
    func testCompleteSnapshotSeriesPreservesChronologicalOrderAcrossPages() async throws {
        server.twoPages = true
        equal(try await client.allMarketSnapshots(marketId: 42, pageSize: 1).compactMap(\.timestamp), [100, 200])
    }
    func testSnapshotRequestRejectsNegativeRuntimeMarketIdBeforeNetworking() async {
        await rejects { _ = try await self.client.marketSnapshots(marketId: -1) }; equal(server.requests.count, 0)
    }
    func testSnapshotRequestRejectsAnOverflowingRuntimeMarketIdBeforeNetworking() async {
        await rejects { _ = try await self.client.marketSnapshots(marketId: Int(UInt32.max) + 1) }; equal(server.requests.count, 0)
    }
    func testSnapshotsRejectDataForAnotherMarket() async {
        server.override = ["marketId": 43]
        await rejects { _ = try await self.client.allMarketSnapshots(marketId: 42) }
    }
    func testSnapshotsRejectAnUnreviewedBlockSeries() async {
        server.override = ["type": "BLOCK"]
        await rejects { _ = try await self.client.marketSnapshots(marketId: 42) }
    }
    func testSnapshotsRejectOutOfOrderPages() async {
        server.twoPages = true; server.override = ["timestamp": 100, "id": "same-snapshot"]
        await rejects { _ = try await self.client.allMarketSnapshots(marketId: 42, pageSize: 1) }
    }
    func testSnapshotsDoNotTreatAnUnfinishedSeriesAsACompleteChart() async {
        server.twoPages = true
        await rejects { _ = try await self.client.allMarketSnapshots(marketId: 42, pageSize: 1, maximumPages: 1) }
    }
    func testSignalsPreserveExactVolumesAndNamedChartBuckets() async throws {
        let signals = try await client.polkamarktSignals()
        equal(signals.totalVolumeUsd.rawValue, "123.000000000000000001")
        equal(signals.liquiditySeries.map(\.label), ["2026-01"])
        equal(signals.answerBreakdown.map(\.answer), ["Yes"])
        equal(signals.accuracySummary?.accuracyPercent, 75)
    }
    func testSignalsRejectWhitespaceOnlyChartLabels() async {
        server.override = ["liquiditySeries": [["label": " ", "value": "1"]]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testSignalsRejectDuplicatedChartBuckets() async {
        server.override = ["liquiditySeries": [["label": "A", "value": "1"], ["label": "A", "value": "2"]]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testSignalsRejectNegativeChartValues() async {
        server.override = ["liquiditySeries": [["label": "A", "value": "-1"]]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testSignalsRejectUntrimmedAnswerLabels() async {
        server.override = ["answerBreakdown": [["answer": " Yes", "volumeUsd": "1", "markets": 1]]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testSignalsRejectNegativeAnswerVolumes() async {
        server.override = ["answerBreakdown": [["answer": "Yes", "volumeUsd": "-1", "markets": 1]]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testSignalsRejectNegativeAnswerMarketCounts() async {
        server.override = ["answerBreakdown": [["answer": "Yes", "volumeUsd": "1", "markets": -1]]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testSignalsRejectAccuracyAboveOneHundredPercent() async {
        server.override = ["accuracySummary": ["accuracyPercent": 100.01]]
        await rejects { _ = try await self.client.polkamarktSignals() }
    }
    func testReferrerRewardCatalogRetainsEveryRewardAndExactTotal() async throws {
        server.twoPages = true
        let rewards = try await client.allReferrerRewards(address: "wallet-a", pageSize: 1)
        equal(rewards.map(\.id), ["reward-1", "reward-2"])
        equal(rewards.compactMap(\.amount).map(\.rawValue), Array(repeating: "123456789012345678901", count: 2))
    }
    func testReferrerRewardCatalogCannotBeReusedForAnotherAccount() async throws {
        _ = try await client.allReferrerRewards(address: "wallet-a")
        server.status = 503
        await rejects { _ = try await self.client.allReferrerRewards(address: "wallet-b") }
    }
    func testReferrerRewardCatalogRejectsMalformedLiveAmountsEvenWhenACompleteCacheExists() async throws {
        _ = try await client.allReferrerRewards(address: "wallet-a")
        server.override = ["amount": "-1"]
        await rejects { _ = try await self.client.allReferrerRewards(address: "wallet-a") }
    }
}

extension PISecondaryReadFlowTests {
    private func legacyHistory(count: Int = 10, page: Int = 1, filter: ((TxHistoryItem) -> KotlinBoolean)? = nil,
                               hash: String? = nil) -> SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>> {
        let canonical = hash ?? server.otherHash
        return SubqueryHistoryOperation(address: "wallet-a", count: count, page: page, filter: filter,
            client: client, canonicalBlockHash: { _ in canonical },
            validatedHistoryCache: PIValidatedHistoryCache(baseURL: directory))
    }
    func testLegacyHistoryAdapterKeepsExactFeeTimestampAndCanonicalIdentifiers() async throws {
        let operation = legacyHistory()
        let page = try await operation.execute()
        let item = try XCTUnwrap(page.items.first as? TxHistoryItem)
        equal(item.id, server.hash); equal(item.blockHash, server.otherHash)
        equal(item.networkFee, "7"); equal(item.timestamp, "100"); XCTAssertTrue(item.success)
        XCTAssertTrue(page.endReached); equal(page.page, 1); equal(operation.historyCoverage, .allRoles); XCTAssertNil(operation.cachedAt)
    }
    func testLegacyHistoryAdapterKeepsJSONScalarAndNestedParametersWithoutRounding() async throws {
        server.override = ["module": "liquidityProxy", "method": "swap", "data": ["n": "9007199254740993", "flag": true, "empty": NSNull(), "object": ["b": 2, "a": 1], "array": [1, 2]]]
        let page = try await legacyHistory().execute()
        let item = try XCTUnwrap(page.items.first as? TxHistoryItem)
        equal(item.module, "liquidityProxy"); equal(item.method, "swap")
        let params = try XCTUnwrap(item.data)
        equal(params.map(\.paramName), ["array", "empty", "flag", "n", "object"])
        equal(params.map(\.paramValue), ["[1,2]", "", "true", "9007199254740993", "{\"a\":1,\"b\":2}"])
    }
    func testLegacyHistoryAdapterMapsNestedCallsAndKeepsTheirOuterHash() async throws {
        server.override = ["calls": ["nodes": [["module": "poolXYK", "method": "withdrawLiquidity", "data": ["amount": "123"]], ["module": NSNull(), "method": NSNull(), "data": NSNull()]]]]
        let page = try await legacyHistory().execute()
        let nested = try XCTUnwrap((page.items.first as? TxHistoryItem)?.nestedData)
        equal(nested.count, 2); equal(nested[0].module, "poolXYK"); equal(nested[0].method, "withdrawLiquidity")
        equal(nested[0].hash, server.hash)
        equal(nested[0].data.first?.paramValue, "123"); equal(nested[1].module, ""); equal(nested[1].method, ""); XCTAssertTrue(nested[1].data.isEmpty)
    }
    func testLegacyHistoryAdapterIgnoresNonobjectParametersWithoutDroppingTheTransaction() async throws {
        server.override = ["data": [1, 2, 3]]
        let page = try await legacyHistory().execute()
        equal(page.items.count, 1); XCTAssertNil((page.items.first as? TxHistoryItem)?.data)
    }
    func testLegacyHistoryAdapterFilterDoesNotChangeRemoteCompletionState() async throws {
        let page = try await legacyHistory(filter: { _ in KotlinBoolean(bool: false) }).execute()
        XCTAssertTrue(page.items.isEmpty); XCTAssertTrue(page.endReached); equal(page.endCursor, "c1")
    }
    func testLegacyHistoryAdapterKeepsAnExplicitFailedExecution() async throws {
        server.override = ["execution": ["success": false]]
        let page = try await legacyHistory().execute()
        equal((page.items.first as? TxHistoryItem)?.success, false)
    }
    func testLegacyHistoryAdapterRejectsAnUnqualifiedBlockHashEvenAfterAGoodRead() async throws {
        _ = try await legacyHistory().execute()
        await rejects { _ = try await self.legacyHistory(hash: "0x" + String(repeating: "ef", count: 32)).execute() }
    }
    func testLegacyHistoryAdapterRejectsInvalidPageBoundsBeforeRequestingAnything() async {
        for (count, page) in [(0, 1), (101, 1), (1, 0), (1, 21)] {
            await rejects { _ = try await self.legacyHistory(count: count, page: page).execute() }
        }
        equal(server.requests.count, 0)
    }
    func testLegacyHistoryAdapterRejectsAnUnsupportedGenericOutputType() async {
        let hash = server.otherHash
        let operation = SubqueryHistoryOperation<String>(address: "wallet-a", count: 10, page: 1, filter: nil,
            client: client, canonicalBlockHash: { _ in hash }, validatedHistoryCache: PIValidatedHistoryCache(baseURL: directory))
        await rejects { _ = try await operation.execute() }
    }
    func testLegacyHistoryAdapterReturnsOnlyPreviouslyVerifiedRowsDuringOutage() async throws {
        let live = try await legacyHistory().execute()
        server.status = 503
        let cachedOperation = legacyHistory()
        let cached = try await cachedOperation.execute()
        equal(cached.items.compactMap { ($0 as? TxHistoryItem)?.id }, live.items.compactMap { ($0 as? TxHistoryItem)?.id }); equal(cached.endReached, live.endReached)
        XCTAssertNotNil(cachedOperation.cachedAt); equal(cachedOperation.historyCoverage, .allRoles)
    }
    func testLegacyHistoryAdapterDoesNotReuseAnotherPageDuringOutage() async throws {
        _ = try await legacyHistory().execute(); server.status = 503
        await rejects { _ = try await self.legacyHistory(page: 2).execute() }
    }
    func testLegacyHistoryAdapterDoesNotMaskInvalidLiveFeesWithCachedHistory() async throws {
        _ = try await legacyHistory().execute(); server.override = ["networkFee": "-7"]
        await rejects { _ = try await self.legacyHistory().execute() }
    }
}

extension PISecondaryReadFlowTests {
    private func assetCacheFile() throws -> URL {
        try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix("MobileAssets_") })
    }
    func testQueryCacheEvictsTheOldestEntryAtItsBoundAndKeepsTheLatestOfflineRead() async throws {
        _ = try await client.assets(first: 1)
        let oldest = try assetCacheFile()
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: oldest.path)
        for size in 2...100 { _ = try await client.assets(first: size) }
        for size in 1...29 { _ = try await client.poolXYKs(first: size) }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        equal(files.filter { $0.pathExtension == "json" }.count, 128)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldest.path))
        server.status = 503
        equal(try await client.assets(first: 100).values.first?.id, WalletAssetId.xor.rawValue)
        await rejects { _ = try await self.client.assets(first: 1) }
    }
    func testMalformedCacheEnvelopeCannotBecomeAnOfflineAssetPrice() async throws {
        _ = try await client.assets(first: 1)
        let file = try assetCacheFile(); try Data("broken".utf8).write(to: file)
        server.status = 503
        await rejects { _ = try await self.client.assets(first: 1) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testFutureDatedCacheCannotBypassTheOfflineAgeLimit() async throws {
        _ = try await client.assets(first: 1)
        let file = try assetCacheFile()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        object["savedAt"] = Date().timeIntervalSinceReferenceDate + 3_600
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        server.status = 503
        await rejects { _ = try await self.client.assets(first: 1) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testCacheDirectoryReplacementDoesNotRedirectWritesThroughASymlink() async throws {
        _ = try await client.assets(first: 1)
        let destination = directory.appendingPathExtension("outside")
        try FileManager.default.moveItem(at: directory, to: destination)
        defer { try? FileManager.default.removeItem(at: destination) }
        try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: destination)
        let before = try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted()
        equal(try await client.assets(first: 2).values.count, 1)
        equal(try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted(), before)
    }
}

final class ValidatedHistoryCacheBoundaryTests: XCTestCase {
    private var directory: URL!
    private var cache: PIValidatedHistoryCache!
    private let fixtureHash = "0x" + String(repeating: "ab", count: 32)
    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cache = PIValidatedHistoryCache(baseURL: directory)
    }
    override func tearDownWithError() throws {
        cache = nil; try FileManager.default.removeItem(at: directory); try super.tearDownWithError()
    }
    private func element(_ address: String = "fixture", overrides: [String: Any] = [:]) throws -> PIHistoryElement {
        let object: [String: Any] = ["id": fixtureHash, "address": address, "timestamp": 1, "blockHeight": 7, "blockHash": fixtureHash, "networkFee": "0", "execution": ["success": true]]
        return try JSONDecoder().decode(PIHistoryElement.self, from: JSONSerialization.data(withJSONObject: object.merging(overrides) { _, new in new }))
    }
    private func save(address: String = "fixture", elements: [PIHistoryElement]? = nil, checkpointHash: String? = nil, count: Int = 10, page: Int = 1, end: Bool = true, cursor: String? = nil) async throws {
        await cache.save(address: address, count: count, page: page, finalizedCheckpoint: 7,
            indexedCheckpointHash: checkpointHash, endCursor: cursor, endReached: end, elements: try elements ?? [element(address)])
    }
    private func files() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("PIValidatedHistoryV1"), includingPropertiesForKeys: nil)
    }
    func testCacheEvictionKeepsTheNewestSixtyFourQualifiedPages() async throws {
        try await save(address: "oldest")
        let oldest = try XCTUnwrap(files().first)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: oldest.path)
        for index in 1...64 { try await save(address: "wallet-\(index)") }
        XCTAssertEqual(try files().count, 64); XCTAssertFalse(FileManager.default.fileExists(atPath: oldest.path))
        let newest = await cache.load(address: "wallet-64", count: 10, page: 1)
        XCTAssertEqual(newest?.elements.first?.address, "wallet-64")
    }
    func testIncompletePageWithoutCursorIsNeverPersisted() async throws {
        try await save(end: false); XCTAssertTrue(try files().isEmpty)
    }
    func testInvalidPageBoundsAreNeverPersisted() async throws {
        for (count, page) in [(0, 1), (101, 1), (10, 0), (10, 21)] { try await save(count: count, page: page) }
        XCTAssertTrue(try files().isEmpty)
    }
    func testMalformedFinalizedHashCannotQualifyACachedPage() async throws {
        try await save(checkpointHash: "0x01"); XCTAssertTrue(try files().isEmpty)
    }
    func testTwoRecordsAtOneHeightCannotDisagreeOnCanonicalBlockHash() async throws {
        try await save(elements: [element(), element(overrides: ["id": "incoming-event", "blockHash": "0x" + String(repeating: "cd", count: 32)])])
        XCTAssertTrue(try files().isEmpty)
    }
    func testRecordAtFinalizedHeightMustMatchTheFinalizedCheckpointHash() async throws {
        try await save(checkpointHash: "0x" + String(repeating: "cd", count: 32))
        XCTAssertTrue(try files().isEmpty)
    }
    func testDuplicateTransactionsCannotBePersistedAsSeparateActivity() async throws {
        let item = try element(); try await save(elements: [item, item]); XCTAssertTrue(try files().isEmpty)
    }
    func testCachedHistoryCannotBeWrittenOverADirectoryEntry() async throws {
        try await save(); let file = try XCTUnwrap(files().first)
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        let sentinel = file.appendingPathComponent("keep"); try Data("keep".utf8).write(to: sentinel)
        try await save(); XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "keep")
    }
    func testReplacingCacheDirectoryWithAFileFailsClosedWithoutChangingThatFile() async throws {
        let path = directory.appendingPathComponent("PIValidatedHistoryV1")
        try FileManager.default.removeItem(at: path); try Data("preserve".utf8).write(to: path)
        try await save()
        let loaded = await cache.load(address: "fixture", count: 10, page: 1)
        XCTAssertNil(loaded); XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), "preserve")
    }
    func testTamperedPayloadIsRemovedInsteadOfDisplayedOffline() async throws {
        try await save(); let file = try XCTUnwrap(files().first)
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        envelope["digest"] = String(repeating: "0", count: 64)
        try JSONSerialization.data(withJSONObject: envelope).write(to: file)
        let loaded = await cache.load(address: "fixture", count: 10, page: 1)
        XCTAssertNil(loaded); XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
}

extension PISecondaryReadFlowTests {
    private var productionPI: URL { URL(string: "https://pi.soramitsu.io/graphql")! }
    private func fiatOperation<T>(_ type: T.Type = T.self) -> SubqueryFiatInfoOperation<T> {
        let client = self.client!
        return SubqueryFiatInfoOperation(baseUrl: productionPI, catalog: { try await client.allAssets() })
    }
    private func apyOperation<T>(_ type: T.Type = T.self) -> SubqueryApyInfoOperation<T> {
        let client = self.client!
        return SubqueryApyInfoOperation(baseUrl: productionPI, catalog: { try await client.allPoolXYKs() })
    }
    func testFiatAdapterPreservesTheExactIndexerPrice() async throws {
        let rows = try await fiatOperation([PIExactFiatData].self).execute()
        equal(rows.map(\.id), [WalletAssetId.xor.rawValue])
        equal(rows.first?.priceUsd?.rawValue, "1.000000000000000001")
        equal(server.requests.filter { $0.operation == "MobileAssets" }.count, 1)
    }
    func testFiatAdapterTreatsMissingAndZeroIndexerPricesAsUnavailable() async throws {
        server.override = ["priceUSD": NSNull()]
        let rows = try await fiatOperation([PIExactFiatData].self).execute()
        XCTAssertNil(rows.first?.priceUsd)
        server.override = ["priceUSD": "0"]
        let zero = try await fiatOperation([PIExactFiatData].self).execute()
        XCTAssertNil(zero.first?.priceUsd)
        equal(zero.map(\.id), rows.map(\.id))
    }
    func testFiatAdapterReturnsAnAuthoritativelyEmptyCatalog() async throws {
        server.empty = true
        let rows = try await fiatOperation([PIExactFiatData].self).execute()
        XCTAssertTrue(rows.isEmpty)
    }
    func testFiatAdapterRejectsTheWrongOutputType() async {
        await rejects { _ = try await self.fiatOperation(String.self).execute() }
    }
    func testFiatAdapterRejectsUnreviewedEndpointsBeforeReadingTheCatalog() async {
        for url in ["http://pi.soramitsu.io/graphql", "https://untrusted.invalid/graphql", "https://pi.soramitsu.io/other"] {
            var loads = 0
            let operation = SubqueryFiatInfoOperation<[PIExactFiatData]>(baseUrl: URL(string: url)!, catalog: { loads += 1; return [] })
            await rejects { _ = try await operation.execute() }
            equal(loads, 0)
        }
    }
    func testFiatAdapterPropagatesAnUnavailableCatalog() async {
        let operation = SubqueryFiatInfoOperation<[PIExactFiatData]>(baseUrl: productionPI, catalog: { throw URLError(.notConnectedToInternet) })
        do { _ = try await operation.execute(); XCTFail("An unavailable price catalog must not become an empty success") }
        catch { equal((error as? URLError)?.code, .notConnectedToInternet) }
    }
    func testApyAdapterPreservesExactBonusApyAndPoolIdentity() async throws {
        server.override = ["strategicBonusApy": "123.000000000000000001"]
        let rows = try await apyOperation([PIExactApyInfo].self).execute()
        equal(rows.map(\.id), ["pool-1"])
        equal(rows.first?.sbApy?.rawValue, "123.000000000000000001")
    }
    func testApyAdapterPreservesAnUnknownBonusApy() async throws {
        let rows = try await apyOperation([PIExactApyInfo].self).execute()
        equal(rows.count, 1); XCTAssertNil(rows.first?.sbApy)
    }
    func testApyAdapterKeepsEveryPageOfThePoolCatalog() async throws {
        server.twoPages = true
        let rows = try await apyOperation([PIExactApyInfo].self).execute()
        equal(rows.map(\.id), ["pool-1", "pool-2"])
    }
    func testApyAdapterRejectsTheWrongOutputType() async {
        await rejects { _ = try await self.apyOperation(String.self).execute() }
    }
    func testApyAdapterRejectsAnUnreviewedEndpointBeforeLoading() async {
        var loads = 0
        let operation = SubqueryApyInfoOperation<[PIExactApyInfo]>(baseUrl: URL(string: "https://untrusted.invalid/graphql")!, catalog: { loads += 1; return [] })
        await rejects { _ = try await operation.execute() }; equal(loads, 0)
    }
    func testApyAdapterPropagatesCatalogFailureWithoutInventingZeroApy() async {
        let operation = SubqueryApyInfoOperation<[PIExactApyInfo]>(baseUrl: productionPI, catalog: { throw PIIndexerError.invalidQuantity })
        do { _ = try await operation.execute(); XCTFail("Malformed APY must fail") }
        catch { guard case PIIndexerError.invalidQuantity = error else { return XCTFail("Unexpected error: \(error)") } }
    }
    private func referralOperation<T>(_ type: T.Type = T.self, count: Int = 1_000) -> SubqueryReferralRewardsOperation<T> {
        SubqueryReferralRewardsOperation(address: "wallet-a", count: count, client: client)
    }
    func testReferralAdapterPreservesExactAmountAndReferralIdentity() async throws {
        let result = try await referralOperation(ReferrerRewardsInfo.self).execute()
        equal(result.rewards.map(\.referral), ["wallet-b"])
        equal(result.rewards.map(\.amount), ["123456789012345678901"])
    }
    func testReferralAdapterFollowsAllRewardPages() async throws {
        server.twoPages = true
        let result = try await referralOperation(ReferrerRewardsInfo.self).execute()
        equal(result.rewards.count, 2)
        equal(server.requests.filter { $0.operation == "MobileReferrerRewards" }.count, 2)
    }
    func testReferralAdapterClampsNonpositiveRequestedCountsToOne() async throws {
        for count in [0, -1, Int.min] {
            _ = try await referralOperation(ReferrerRewardsInfo.self, count: count).execute()
            equal(server.requests.last(where: { $0.operation == "MobileReferrerRewards" })?.variables["first"] as? Int, 1)
        }
    }
    func testReferralAdapterCapsOversizedRequestPagesAtOneHundred() async throws {
        _ = try await referralOperation(ReferrerRewardsInfo.self, count: Int.max).execute()
        equal(server.requests.last(where: { $0.operation == "MobileReferrerRewards" })?.variables["first"] as? Int, 100)
    }
    func testReferralAdapterNeverReturnsAPartialCatalogAtItsPageLimit() async {
        server.twoPages = true
        await rejects { _ = try await self.referralOperation(ReferrerRewardsInfo.self, count: 1).execute() }
    }
    func testReferralAdapterRejectsARewardWithoutAnExactAmountOrReferral() async {
        for field in ["amount", "referral"] {
            server.override = [field: NSNull()]
            await rejects { _ = try await self.referralOperation(ReferrerRewardsInfo.self).execute() }
        }
    }
    func testReferralAdapterRejectsTheWrongOutputType() async {
        await rejects { _ = try await self.referralOperation(String.self).execute() }
    }
    func testReferralAdapterReturnsAnAuthoritativelyEmptyRewardSet() async throws {
        server.empty = true
        let result = try await referralOperation(ReferrerRewardsInfo.self).execute()
        XCTAssertTrue(result.rewards.isEmpty)
    }
    private func serveMobileConfig(onResponse: (() -> Void)? = nil) throws {
        let config = String(data: try PIIndexerFixture.data("mobile-config"), encoding: .utf8)!
        PIStubIndexerProtocol.install { [server] request in
            if request.operation == "MobileConfig" {
                onResponse?()
                return .init(body: config)
            }
            return server.respond(request)
        }
    }
    func testConfigAdapterProjectsNodesFromTheSameQualifiedLiveHealth() async throws {
        try serveMobileConfig()
        let settings = InMemorySettingsManager()
        defer { ProductionRemoteCapabilitySession.shared.invalidate() }
        let result = try await SubqueryConfigInfoOperation<SoraConfig>(client: client, settings: settings).execute()
        equal(result.nodes.map(\.name), ["Sora"])
        equal(result.nodes.map(\.address), ["wss://mof2.sora.org"])
        equal(result.genesis, PIIndexerClient.soraMainnetGenesis)
        equal(result.blockExplorerType.fiat, "pi")
        equal(result.blockExplorerType.reward, "pi")
        XCTAssertFalse(result.soracard); XCTAssertTrue(result.currencies.isEmpty)
        XCTAssertFalse(settings.nexusSendsEnabled); XCTAssertFalse(settings.polkamarktMutationsEnabled)
    }
    func testConfigAdapterRejectsTheWrongOutputTypeBeforePersistingFlags() async throws {
        try serveMobileConfig()
        let settings = InMemorySettingsManager()
        defer { ProductionRemoteCapabilitySession.shared.invalidate() }
        await rejects { _ = try await SubqueryConfigInfoOperation<String>(client: self.client, settings: settings).execute() }
        XCTAssertTrue(settings.allKeys().isEmpty)
    }
    func testConfigAdapterFailureRevokesTheRefreshWithoutWritingSettings() async {
        let settings = InMemorySettingsManager()
        defer { ProductionRemoteCapabilitySession.shared.invalidate() }
        server.status = 503
        await rejects { _ = try await SubqueryConfigInfoOperation<SoraConfig>(client: self.client, settings: settings).execute() }
        XCTAssertTrue(settings.allKeys().isEmpty)
        XCTAssertFalse(ProductionRemoteCapabilitySession.shared.permitsMutation(localQualification: true, capability: .nexusSends))
    }
    func testConfigAdapterCannotPublishAfterANewerRefreshSupersedesIt() async throws {
        try serveMobileConfig(onResponse: { _ = ProductionRemoteCapabilitySession.shared.beginLiveRefresh() })
        let settings = InMemorySettingsManager()
        defer { ProductionRemoteCapabilitySession.shared.invalidate() }
        await rejects { _ = try await SubqueryConfigInfoOperation<SoraConfig>(client: self.client, settings: settings).execute() }
        XCTAssertTrue(settings.allKeys().isEmpty)
    }
}
