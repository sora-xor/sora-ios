// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import XCTest
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
        let prior = request.variables["after"] as? String != nil, index = prior && !repeatID ? 2 : 1
        let market: [String:Any] = ["id":"market-42","marketId":42,"status":"Open","updatedAtBlock":marketHeight,"timestamp":100]
        let name: String; let row: [String:Any]
        switch request.operation {
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
