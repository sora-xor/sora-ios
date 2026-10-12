// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Combine
import Foundation
import RobinHood
import SSFUtils
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest
import sorawallet
@testable import SoraPassport

// Audit finding I4 (10 October 2026): fiat prices and market data never
// loaded from the live PI indexer. Two independent causes:
//
// 1. PI sends `volumeDayUSD` and `volumeWeekUSD` as JSON numbers; the client
//    decoded quantities from strings only, so every asset page failed.
// 2. The client required PI's checkpoint to stay identical across a read of
//    up to 30 requests, while PI indexes a block every six seconds.
//
// These tests run the production client against responses captured from the
// live indexer (`PIIndexerFixtures`), against a stub indexer that keeps
// indexing between requests, and, when asked, against the live indexer.

// MARK: - Fixtures

enum PIIndexerFixture {
    /// When `health.json` was captured: the `Date` header of that response.
    static let healthDateHeader = "Sun, 11 Oct 2026 01:00:01 GMT"
    static let healthEpochSeconds = 1_791_680_401

    static func data(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Data {
        let bundle = Bundle(for: PIIndexerWireContractTests.self)
        let url = try XCTUnwrap(
            bundle.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "PIIndexerFixtures"
            ),
            "Missing fixture \(name).json",
            file: file,
            line: line
        )
        return try Data(contentsOf: url)
    }

    /// The asset rows of `assets-page.json`, each exactly as PI sent it.
    static func assetRows() throws -> [String] {
        let text = try XCTUnwrap(
            String(data: data("assets-page"), encoding: .utf8)
        )
        let start = try XCTUnwrap(text.range(of: #""nodes":["#)).upperBound
        let end = try XCTUnwrap(text.range(of: #"],"pageInfo""#)).lowerBound
        // Asset rows are flat objects, so `},{` only occurs between rows.
        let rows = text[start ..< end]
            .dropFirst()
            .dropLast()
            .components(separatedBy: "},{")
            .map { "{\($0)}" }
        XCTAssertEqual(rows.count, 8)
        return rows
    }
}

// MARK: - A stub indexer

/// Answers the client's requests from a closure. `requests` records every
/// operation in order.
final class PIStubIndexerProtocol: URLProtocol {
    struct Response {
        var status = 200
        var body: String
        /// `nil` sends the current time, as a real server does.
        var dateHeader: String?
        var omitsDateHeader = false
        /// What a sign-in page or a firewall sends instead of JSON.
        var contentType = "application/json"
        /// The request is lost on the way: no response at all.
        var transportError: URLError.Code?
    }

    struct Request {
        let operation: String
        let variables: [String: Any]
    }

    private static let lock = NSLock()
    private static var handler: ((Request) -> Response)?
    private static var recorded: [String] = []

    static func install(_ handler: @escaping (Request) -> Response) {
        lock.lock()
        self.handler = handler
        recorded = []
        lock.unlock()
    }

    static func uninstall() {
        lock.lock()
        handler = nil
        recorded = []
        lock.unlock()
    }

    static var requests: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PIStubIndexerProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    static func httpDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        return formatter.string(from: date)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = Self.body(of: request)
        let object = (try? JSONSerialization.jsonObject(with: body))
            as? [String: Any]
        let stubRequest = Request(
            operation: object?["operationName"] as? String ?? "",
            variables: object?["variables"] as? [String: Any] ?? [:]
        )
        Self.lock.lock()
        Self.recorded.append(stubRequest.operation)
        let handler = Self.handler
        Self.lock.unlock()
        let stub = handler?(stubRequest)
            ?? Response(status: 500, body: "{}")
        if let code = stub.transportError {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        var headers = ["Content-Type": stub.contentType]
        if !stub.omitsDateHeader {
            headers["Date"] = stub.dateHeader ?? Self.httpDate(Date())
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// A PI indexer whose checkpoint the test moves. It serves the captured
/// asset rows in pages of three.
final class PIAdvancingIndexer {
    private let lock = NSLock()
    private var height: Int
    private var healthReads = 0
    /// Called for every health request with its 1-based number; returns the
    /// indexed height to report.
    var heightForHealthRead: ((Int, Int) -> Int)?
    /// Seconds added to the indexer's clock (its timestamps and `Date`
    /// header) relative to this device.
    var clockOffset: TimeInterval = 0
    /// How old the last indexed block is, by the indexer's own clock.
    var indexAge = 2
    var serviceId = "pi.soramitsu.io"
    /// `false` is what PI reports while it restarts.
    var workerStartupComplete = true
    /// PI's "last indexed" time changes only when it indexes a block, so
    /// two health reads at one height are identical, as on the live
    /// service.
    private var stamp: (height: Int, indexAge: Int, clockOffset: TimeInterval, indexedAt: Int)?
    var assetRows: [String]
    /// The `totalCount` to report for a page request, by its 1-based number.
    var totalCountForPageRead: ((Int) -> Int)?
    var failsPagesWithStatus: Int?
    /// What to answer a page request with instead of the page, by its
    /// 1-based number; `nil` answers normally.
    var answerForPageRead: ((Int) -> PIStubIndexerProtocol.Response?)?
    /// The same for a health request.
    var answerForHealthRead: ((Int) -> PIStubIndexerProtocol.Response?)?
    private var pageReads = 0

    init(height: Int = 27_992_164, assetRows: [String]) {
        self.height = height
        self.assetRows = assetRows
    }

    func respond(
        to request: PIStubIndexerProtocol.Request
    ) -> PIStubIndexerProtocol.Response {
        lock.lock()
        defer { lock.unlock() }
        let serverNow = Date().addingTimeInterval(clockOffset)
        let dateHeader = PIStubIndexerProtocol.httpDate(serverNow)
        switch request.operation {
        case "MobileHealth":
            healthReads += 1
            if let answer = answerForHealthRead?(healthReads) {
                return answer
            }
            height = heightForHealthRead?(healthReads, height) ?? height
            let indexedAt: Int
            if let stamp, stamp.height == height, stamp.indexAge == indexAge,
               stamp.clockOffset == clockOffset {
                indexedAt = stamp.indexedAt
            } else {
                indexedAt = Int(serverNow.timeIntervalSince1970) - indexAge
                stamp = (height, indexAge, clockOffset, indexedAt)
            }
            return .init(
                body: Self.health(
                    indexed: height,
                    finalized: height + 1,
                    indexedAt: indexedAt,
                    serviceId: serviceId,
                    workerStartupComplete: workerStartupComplete
                ),
                dateHeader: dateHeader
            )
        case "MobileAssets":
            pageReads += 1
            if let status = failsPagesWithStatus {
                return .init(status: status, body: "{}", dateHeader: dateHeader)
            }
            if let answer = answerForPageRead?(pageReads) {
                return answer
            }
            let first = request.variables["first"] as? Int ?? 0
            let after = request.variables["after"] as? String
            let start = after.flatMap { Int($0.dropFirst(1)) } ?? 0
            let end = min(start + first, assetRows.count)
            let rows = Array(assetRows[start ..< end])
            let total = totalCountForPageRead?(pageReads) ?? assetRows.count
            return .init(
                body: """
                {"data":{"assets":{"nodes":[\(rows.joined(separator: ","))],\
                "pageInfo":{"hasNextPage":\(end < assetRows.count),\
                "hasPreviousPage":\(after != nil),\
                "startCursor":"s\(start)","endCursor":"c\(end)"},\
                "totalCount":\(total)}}}
                """,
                dateHeader: dateHeader
            )
        default:
            return .init(status: 500, body: "{}", dateHeader: dateHeader)
        }
    }

    static func health(
        indexed: Int,
        finalized: Int,
        indexedAt: Int,
        serviceId: String = "pi.soramitsu.io",
        workerStartupComplete: Bool = true
    ) -> String {
        """
        {"data":{"_health":{"ok":true,"repositoryReady":true,\
        "service":"polkaswap-indexer","serviceId":"\(serviceId)",\
        "schemaVersion":1,"ecosystem":"sora2","chainId":"sora:mainnet",\
        "network":"mainnet","publicBaseUrl":"https://pi.soramitsu.io/graphql",\
        "readOnly":true,"workerAvailable":true,"workerReady":true,\
        "workerLatestFinalizedBlock":\(finalized),\
        "workerLatestIndexedBlock":\(indexed),\
        "workerLag":\(finalized - indexed),"workerReadinessReason":null,\
        "workerLifecycle":"running",\
        "workerStartupComplete":\(workerStartupComplete),\
        "workerLastSuccessfulIndexTimestamp":\(indexedAt),\
        "workerLastError":null,"workerLastErrorTimestamp":null}}}
        """
    }
}

// MARK: - Decoding the live wire format

final class PIIndexerWireContractTests: XCTestCase {
    private struct AssetsPayload: Decodable {
        let assets: PIConnection<PIAsset>
    }

    private struct PoolsPayload: Decodable {
        let poolXYKs: PIConnection<PIPoolXYK>
    }

    private struct HistoryPayload: Decodable {
        let historyElements: PIConnection<PIHistoryElement>
    }

    private struct RewardsPayload: Decodable {
        let referrerRewards: PIConnection<PIReferrerReward>
    }

    private static let xor =
        "0x0200000000000000000000000000000000000000000000000000000000000000"

    func testCapturedAssetPageDecodesAndValidates() throws {
        let page = try PIIndexerClient.decodeResponse(
            AssetsPayload.self,
            from: PIIndexerFixture.data("assets-page")
        ).assets

        try PIIndexerClient.validateConnectionPage(
            page,
            requestedSize: 8,
            hasPriorPage: true,
            itemIdentity: { $0.id }
        )
        try PIIndexerClient.validateAssets(page.values)
        XCTAssertEqual(page.totalCount, 957)
        XCTAssertEqual(page.values.count, 8)
        let xor = try XCTUnwrap(page.values.first { $0.id == Self.xor })
        // Exactly the text PI sent.
        XCTAssertEqual(xor.priceUSD?.rawValue, "5.40462719")
        XCTAssertEqual(xor.liquidity?.rawValue, "375349458646202884981")
        XCTAssertEqual(xor.priceChangeDay, -10.363275404040861)
        // What the market-cap read needs from every row.
        for asset in page.values {
            XCTAssertNoThrow(
                try PIMarketCapLiquidityValidator.validatedWireValue(
                    asset.liquidity
                ),
                asset.id
            )
        }

        let firstPage = try PIIndexerClient.decodeResponse(
            AssetsPayload.self,
            from: PIIndexerFixture.data("assets-first-page")
        ).assets
        try PIIndexerClient.validateConnectionPage(
            firstPage,
            requestedSize: 4,
            hasPriorPage: false,
            itemIdentity: { $0.id }
        )
        try PIIndexerClient.validateAssets(firstPage.values)
    }

    /// The response every iOS client rejected on 10 October: the query the
    /// candidate sent, answered with `volumeDayUSD` and `volumeWeekUSD` as
    /// JSON numbers.
    func testResponseWithNumericVolumesDecodes() throws {
        let data = try PIIndexerFixture.data("assets-page-with-volumes")
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains(#""volumeDayUSD":7073.59914532"#))
        XCTAssertTrue(text.contains(#""volumeWeekUSD":4533760.99072203"#))

        let page = try PIIndexerClient.decodeResponse(
            AssetsPayload.self,
            from: data
        ).assets
        try PIIndexerClient.validateAssets(page.values)
        XCTAssertEqual(page.values.count, 8)
        XCTAssertEqual(
            page.values.first { $0.id == Self.xor }?.priceUSD?.rawValue,
            "5.40462719"
        )
    }

    /// A quantity PI sends as a JSON number keeps every digit it was sent
    /// with: it is read from the text of the response, not through Double.
    func testNumericQuantitiesFromTheLiveResponseAreExact() throws {
        struct VolumeRow: Decodable, Equatable {
            let id: String
            let volumeDayUSD: PIQuantity
            let volumeWeekUSD: PIQuantity?
        }
        struct Payload: Decodable {
            let assets: PIConnection<VolumeRow>
        }
        let rows = try PIIndexerClient.decodeResponse(
            Payload.self,
            from: PIIndexerFixture.data("assets-page-with-volumes")
        ).assets.values

        let xor = try XCTUnwrap(rows.first { $0.id == Self.xor })
        XCTAssertEqual(xor.volumeDayUSD.rawValue, "7073.59914532")
        XCTAssertEqual(xor.volumeWeekUSD?.rawValue, "4533760.99072203")
        // An integer token (`"volumeDayUSD":3`).
        XCTAssertEqual(rows.last?.volumeDayUSD.rawValue, "3")
        XCTAssertEqual(rows.last?.volumeWeekUSD?.rawValue, "127.25355726")
    }

    func testQuantityAcceptsStringOrNumberWithoutLosingPrecision() throws {
        struct Row: Decodable {
            let long: PIQuantity
            let small: PIQuantity
            let negative: PIQuantity
            let shifted: PIQuantity
            let zero: PIQuantity
            let string: PIQuantity
            let absent: PIQuantity?
            let null: PIQuantity?
        }
        struct Payload: Decodable {
            let rows: [Row]
        }
        let document = """
        {"data":{"rows":[{"long":0,"small":0,"negative":0,"shifted":0,"zero":1,"string":"7"},\
        {"long":123456789012345678901234567890.123456789012345678,\
        "small":1e-7,"negative":-2.5E+3,"shifted":0.5e1,"zero":0,\
        "string":"1.50","null":null}]}}
        """
        let rows = try PIIndexerClient.decodeResponse(
            Payload.self,
            from: Data(document.utf8)
        ).rows

        // The second array element: paths are followed through arrays.
        let row = rows[1]
        XCTAssertEqual(
            row.long.rawValue,
            "123456789012345678901234567890.123456789012345678"
        )
        XCTAssertEqual(row.small.rawValue, "0.0000001")
        XCTAssertEqual(row.negative.rawValue, "-2500")
        XCTAssertEqual(row.shifted.rawValue, "5")
        XCTAssertEqual(row.zero.rawValue, "0")
        XCTAssertEqual(row.string.rawValue, "1.50")
        XCTAssertNil(row.absent)
        XCTAssertNil(row.null)
        XCTAssertEqual(rows[0].zero.rawValue, "1")

        XCTAssertEqual(
            try PIQuantity.plainDecimal(fromJSONNumber: "1.25e1"),
            "12.5"
        )
        XCTAssertEqual(
            try PIQuantity.plainDecimal(fromJSONNumber: "120e-2"),
            "1.2"
        )
        XCTAssertEqual(
            try PIQuantity.plainDecimal(fromJSONNumber: "42"),
            "42"
        )
        // An exponent that would expand without bound is refused.
        XCTAssertThrowsError(
            try PIQuantity.plainDecimal(fromJSONNumber: "1e999999")
        )
    }

    func testQuantityStillRejectsValuesThatAreNotDecimalNumbers() {
        struct Payload: Decodable {
            let value: PIQuantity
        }
        for token in ["true", "{}", "[1]", #""1e3""#, #""0x10""#, #""""#] {
            XCTAssertThrowsError(
                try PIIndexerClient.decodeResponse(
                    Payload.self,
                    from: Data(#"{"data":{"value":\#(token)}}"#.utf8)
                ),
                token
            )
        }
        // Without the response text (a plain decoder) a number fails closed
        // instead of being rounded through Double.
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PIQuantity.self,
                from: Data("1.5".utf8)
            )
        )
    }

    func testPriceChangeAcceptsNumberOrDecimalString() throws {
        let decoder = JSONDecoder()
        let number = try decoder.decode(
            PIAsset.self,
            from: Data(#"{"id":"xor","priceChangeDay":-3.5}"#.utf8)
        )
        let integer = try decoder.decode(
            PIAsset.self,
            from: Data(#"{"id":"xor","priceChangeDay":0}"#.utf8)
        )
        let string = try decoder.decode(
            PIAsset.self,
            from: Data(#"{"id":"xor","priceChangeDay":"-3.5"}"#.utf8)
        )
        let absent = try decoder.decode(
            PIAsset.self,
            from: Data(#"{"id":"xor","priceChangeDay":null}"#.utf8)
        )
        XCTAssertEqual(number.priceChangeDay, -3.5)
        XCTAssertEqual(integer.priceChangeDay, 0)
        XCTAssertEqual(string.priceChangeDay, -3.5)
        XCTAssertNil(absent.priceChangeDay)
        XCTAssertThrowsError(
            try decoder.decode(
                PIAsset.self,
                from: Data(#"{"id":"xor","priceChangeDay":"up"}"#.utf8)
            )
        )
    }

    func testCapturedPoolPageDecodesAndValidates() throws {
        let page = try PIIndexerClient.decodeResponse(
            PoolsPayload.self,
            from: PIIndexerFixture.data("pools-first-page")
        ).poolXYKs

        try PIIndexerClient.validateConnectionPage(
            page,
            requestedSize: 4,
            hasPriorPage: false,
            itemIdentity: { $0.id }
        )
        try PIIndexerClient.validatePools(page.values)
        XCTAssertEqual(page.totalCount, 432)
        XCTAssertEqual(page.values.count, 4)
        let pool = try XCTUnwrap(page.values.first)
        XCTAssertEqual(pool.baseAssetReserves?.rawValue, "9650269498613789924")
        // PI identifies a pool by its asset pair, not by its reserves
        // account.
        XCTAssertEqual(
            pool.id,
            "\(try XCTUnwrap(pool.baseAssetId))-\(try XCTUnwrap(pool.targetAssetId))"
        )
    }

    func testPoolAPYIsFoundByAssetPairAndZeroIsNotShown() throws {
        let pools = try PIIndexerClient.decodeResponse(
            PoolsPayload.self,
            from: PIIndexerFixture.data("pools-first-page")
        ).poolXYKs.values
        let live = try XCTUnwrap(pools.first)
        let base = try XCTUnwrap(live.baseAssetId)
        let target = try XCTUnwrap(live.targetAssetId)

        XCTAssertEqual(
            APYService.pool(
                in: pools,
                baseAssetId: base,
                targetAssetId: target
            ),
            live
        )
        XCTAssertNil(
            APYService.pool(
                in: pools,
                baseAssetId: target,
                targetAssetId: base
            )
        )
        // PI publishes 0 for every pool today. That is not shown as "0%".
        XCTAssertEqual(live.strategicBonusApy?.rawValue, "0")
        XCTAssertNil(APYService.presentableApy(live.strategicBonusApy))
        XCTAssertNil(APYService.presentableApy(nil))
        XCTAssertEqual(
            APYService.presentableApy(try PIQuantity("0.125")),
            Decimal(string: "0.125")
        )
    }

    func testCapturedHistoryPageDecodesAndPassesAccountValidation()
        async throws
    {
        let account = "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy"
        let page = try PIIndexerClient.decodeResponse(
            HistoryPayload.self,
            from: PIIndexerFixture.data("history-signer-page")
        ).historyElements

        try PIIndexerClient.validateConnectionPage(
            page,
            requestedSize: 4,
            hasPriorPage: false,
            itemIdentity: {
                PIHistoryCheckpointValidator.canonicalHistoryIdentifier($0.id)
                    ?? ""
            }
        )
        try PIIndexerClient.validateAccountHistory(
            page.values,
            account: account
        )
        let values = try PIHistoryPageValidator.validate(
            page,
            hasPriorPage: false,
            pageSize: 4
        )
        XCTAssertEqual(values.count, 4)
        XCTAssertEqual(page.totalCount, 304)
        XCTAssertTrue(values.allSatisfy { $0.address == account })
        XCTAssertEqual(values.first?.networkFee?.rawValue, "1348956171934479284")
        XCTAssertEqual(values.first?.blockHeight, 27_989_372)
        // The Activity pipeline's own checks, with the block hashes PI gave.
        let hashes = Dictionary(
            uniqueKeysWithValues: values.compactMap { element in
                element.blockHeight.flatMap { height in
                    element.blockHash.map { (height, $0) }
                }
            }
        )
        try await PIHistoryCheckpointValidator.validate(
            values,
            expectedAddress: account,
            finalizedCheckpoint: 27_992_164,
            canonicalBlockHash: { height in hashes[height] }
        )

        // The pending-transaction lookup shape.
        let byHash = try PIIndexerClient.decodeResponse(
            HistoryPayload.self,
            from: PIIndexerFixture.data("history-by-hash")
        ).historyElements
        try PIIndexerClient.validateAccountHistory(
            byHash.values,
            account: account,
            expectedTransactionHashes: Set(values.prefix(2).compactMap {
                PIHistoryCheckpointValidator.normalizedTransactionHash($0.id)
            })
        )
        XCTAssertEqual(byHash.values.count, 2)
    }

    func testCapturedRejectionsAreSchemaErrorsThatSelectTheFallback() {
        for name in [
            "history-all-roles-rejected",
            "referrer-rewards-timestamp-order-rejected",
        ] {
            XCTAssertThrowsError(
                try PIIndexerClient.decodeResponse(
                    HistoryPayload.self,
                    from: PIIndexerFixture.data(name)
                ),
                name
            ) { error in
                guard
                    let error = error as? PIIndexerError,
                    case .graphQLErrors = error
                else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertTrue(PIIndexerClient.indicatesUnsupportedSchema(error))
            }
        }
    }

    func testCapturedReferrerRewardsDecodeAndValidate() throws {
        let referrer = "cnXFF4GNDVnynZsCYD95p3Nj3G52LkiPyPikSz1JAxcV5xu8c"
        let page = try PIIndexerClient.decodeResponse(
            RewardsPayload.self,
            from: PIIndexerFixture.data("referrer-rewards-page")
        ).referrerRewards
        let health = try capturedHealth()

        try PIIndexerClient.validateConnectionPage(
            page,
            requestedSize: 100,
            hasPriorPage: false,
            itemIdentity: { $0.id }
        )
        try PIIndexerClient.validateReferrerRewards(
            page.values,
            account: referrer,
            qualification: PIReadQualification(health: health, source: .live)
        )
        XCTAssertEqual(page.values.count, 1)
        XCTAssertEqual(page.values.first?.amount?.rawValue, "0")
        XCTAssertEqual(page.values.first?.blockHeight, "27992150")
    }

    private func capturedHealth() throws -> PIHealth {
        struct Payload: Decodable { let _health: PIHealth }
        return try PIIndexerClient.decodeResponse(
            Payload.self,
            from: PIIndexerFixture.data("health")
        )._health
    }

    func testCapturedHealthIsValidAtTheTimeItsDateHeaderReports() throws {
        let health = try capturedHealth()
        XCTAssertEqual(health.workerLatestIndexedBlock, 27_992_164)
        XCTAssertEqual(health.workerLastSuccessfulIndexTimestamp, 1_791_680_399)
        XCTAssertEqual(
            PIIndexerClient.httpDate(PIIndexerFixture.healthDateHeader)?
                .timeIntervalSince1970,
            TimeInterval(PIIndexerFixture.healthEpochSeconds)
        )
        XCTAssertNoThrow(
            try PIIndexerClient.validateHealth(
                health,
                nowEpochSeconds: PIIndexerFixture.healthEpochSeconds
            )
        )
    }

    func testCapturedMobileConfigDecodesWithItsFlagsOn() throws {
        struct Payload: Decodable { let mobileConfig: PIMobileConfig }
        let config = try PIIndexerClient.decodeResponse(
            Payload.self,
            from: PIIndexerFixture.data("mobile-config")
        ).mobileConfig

        try PIIndexerClient.validateMobileConfig(config)
        XCTAssertEqual(config.nodes.map(\.name), ["Sora"])
        // What the production indexer publishes today.
        XCTAssertTrue(config.nexusAvailable)
        XCTAssertTrue(config.polkamarktVisible)
        XCTAssertTrue(config.tairaDefaultVisible)
        XCTAssertFalse(config.nexusSendsAvailable)
        XCTAssertFalse(config.polkamarktMutationsAvailable)
    }
}

// MARK: - Device clock

final class PIIndexerClockTests: XCTestCase {
    /// Review round 4: the server's time is used however far the device
    /// clock is from it. A phone whose date was set two days back, or a
    /// year ahead, judges PI's timestamps by PI's own clock.
    func testAWellFormedServerDateReplacesTheDeviceClock() {
        let device = Date(timeIntervalSince1970: 1_791_680_000)
        for skew in [
            -7_200, -31, 0, 45, 3_600, 26 * 3_600,
            27 * 3_600, -3 * 24 * 3_600, 400 * 24 * 3_600,
        ] {
            let server = device.addingTimeInterval(TimeInterval(skew))
            let clock = PIIndexerClient.responseClock(
                dateHeader: PIStubIndexerProtocol.httpDate(server),
                deviceNow: device
            )
            XCTAssertEqual(clock.nowEpochSeconds, 1_791_680_000 + skew)
            XCTAssertEqual(clock.deviceSkewSeconds, skew)
        }
    }

    func testMissingOrMalformedServerDateFallsBackToTheDeviceClock() {
        let device = Date(timeIntervalSince1970: 1_791_680_000)
        let untrusted: [String?] = [
            nil,
            "",
            "yesterday",
            "2026-10-11T01:00:01Z",
            "Sun, 11 Oct 2026 01:00:01 JST",
        ]
        for header in untrusted {
            XCTAssertEqual(
                PIIndexerClient.responseClock(
                    dateHeader: header,
                    deviceNow: device
                ),
                PIIndexerClient.ResponseClock(
                    nowEpochSeconds: 1_791_680_000,
                    deviceSkewSeconds: 0
                ),
                header ?? "nil"
            )
        }
    }
}

// MARK: - Reads against an indexer that keeps indexing

final class PIIndexerAdvancingReadTests: XCTestCase {
    private var cacheDirectory: URL!
    private var pauses: [TimeInterval] = []
    private let pauseLock = NSLock()

    override func setUpWithError() throws {
        try super.setUpWithError()
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "pi-tests-\(UUID().uuidString)",
                isDirectory: true
            )
        pauses = []
    }

    override func tearDown() {
        PIStubIndexerProtocol.uninstall()
        try? FileManager.default.removeItem(at: cacheDirectory)
        super.tearDown()
    }

    private func client() -> PIIndexerClient {
        PIIndexerClient(
            session: PIStubIndexerProtocol.session(),
            historyShapeMemory: PIHistoryShapeMemory(),
            cacheDirectory: cacheDirectory,
            retryPause: { [weak self] seconds in
                self?.pauseLock.lock()
                self?.pauses.append(seconds)
                self?.pauseLock.unlock()
            }
        )
    }

    private func indexer() throws -> PIAdvancingIndexer {
        let indexer = PIAdvancingIndexer(
            assetRows: try PIIndexerFixture.assetRows()
        )
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        return indexer
    }

    private func healthReads() -> Int {
        PIStubIndexerProtocol.requests.filter { $0 == "MobileHealth" }.count
    }

    private func pageReads() -> Int {
        PIStubIndexerProtocol.requests.filter { $0 == "MobileAssets" }.count
    }

    /// The case that failed for every user far from the server: PI indexes
    /// a new block between any two requests of the walk.
    func testAllAssetsCompletesWhileTheIndexerAdvancesOnEveryRequest()
        async throws
    {
        let indexer = try indexer()
        indexer.heightForHealthRead = { _, height in height + 1 }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(Set(read.value.map(\.id)).count, 8)
        XCTAssertEqual(read.qualification?.source, .live)
        // Attributed to the checkpoint after the last page: four health
        // reads moved the indexer four blocks.
        XCTAssertEqual(
            read.qualification?.health.workerLatestIndexedBlock,
            27_992_168
        )
        XCTAssertEqual(
            read.value.first?.priceUSD?.rawValue,
            "5.40462719"
        )
        // Three pages cost three page requests and four health requests:
        // each postflight is the next page's preflight.
        XCTAssertEqual(pageReads(), 3)
        XCTAssertEqual(healthReads(), 4)
        XCTAssertTrue(pauses.isEmpty)
    }

    func testFiatPricesComeFromAWalkOverAnAdvancingIndexer() async throws {
        let indexer = try indexer()
        indexer.heightForHealthRead = { _, height in height + 1 }
        let client = client()
        let service = FiatService(assets: {
            try await client.allAssets(pageSize: 3, maximumPages: 5)
        })

        let prices = await service.getFiat()

        XCTAssertEqual(prices.count, 8)
        XCTAssertEqual(
            prices.first {
                $0.id == "0x0200000000000000000000000000000000000000000000000000000000000000"
            }?.priceUsd?.rawValue,
            "5.40462719"
        )
    }

    /// One backwards step (another replica answered) fails that walk; the
    /// walk is run again and completes.
    func testABackwardsCheckpointIsRetriedAndThenAccepted() async throws {
        let indexer = try indexer()
        indexer.heightForHealthRead = { read, height in
            // The third health read reports an earlier block.
            read == 3 ? height - 5 : height + 1
        }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(read.qualification?.source, .live)
        XCTAssertEqual(pauses.count, 1)
        // The failed walk stopped at its second page; the second walk read
        // all three.
        XCTAssertEqual(pageReads(), 2 + 3)
    }

    /// A row registered while the walk runs changes the count between two
    /// pages. With a moving checkpoint that restarts the walk; it is not a
    /// broken response.
    func testACountThatChangesWhileTheIndexerAdvancesRestartsTheWalk()
        async throws
    {
        let indexer = try indexer()
        indexer.heightForHealthRead = { _, height in height + 1 }
        indexer.totalCountForPageRead = { read in read == 2 ? 9 : 8 }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(pauses.count, 1)
        XCTAssertEqual(pageReads(), 2 + 3)
    }

    /// The same change with an unchanged checkpoint is a contradiction in
    /// PI's answer and still fails.
    func testACountThatChangesAtOneCheckpointIsStillRejected() async throws {
        let indexer = try indexer()
        indexer.totalCountForPageRead = { read in read == 2 ? 9 : 8 }

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A contradictory count at one checkpoint was accepted")
        } catch {
            guard case PIIndexerError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(pauses.isEmpty)
    }

    /// PI keeps going backwards: the walk is retried a bounded number of
    /// times, then the last good catalog is returned instead of nothing,
    /// also by a new client after an app restart.
    func testAPersistentlyInconsistentIndexerGivesTheLastGoodCatalog()
        async throws
    {
        let indexer = try indexer()
        let good = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )
        XCTAssertEqual(good.qualification?.source, .live)

        // Every postflight is behind its preflight from now on.
        indexer.heightForHealthRead = { read, height in
            read.isMultiple(of: 2) ? height - 3 : height + 1
        }
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }

        let restarted = client()
        let fallback = try await restarted.qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(fallback.qualification?.source, .cache)
        XCTAssertEqual(fallback.value, good.value)
        XCTAssertEqual(
            fallback.qualification?.health,
            good.qualification?.health
        )
        // Bounded: the first walk and two retries, one page each.
        XCTAssertEqual(pauses.count, PIIndexerClient.maximumStaleCheckpointRetries)
        XCTAssertEqual(
            pageReads(),
            1 + PIIndexerClient.maximumStaleCheckpointRetries
        )
    }

    func testAnIndexerThatStoppedIndexingGivesTheLastGoodCatalog()
        async throws
    {
        let indexer = try indexer()
        let good = try await client().allAssets(pageSize: 3, maximumPages: 5)

        // The last indexed block is ten minutes old by PI's own clock.
        indexer.indexAge = 600
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.qualification?.source, .cache)
        XCTAssertEqual(read.value, good)
        // No page is requested from an indexer that is not fresh, and the
        // health read is not repeated at more than one level.
        XCTAssertEqual(pageReads(), 0)
        XCTAssertEqual(
            healthReads(),
            1 + PIIndexerClient.maximumStaleCheckpointRetries
        )
    }

    func testAnUnreachableIndexerGivesTheLastGoodCatalog() async throws {
        let indexer = try indexer()
        let good = try await client().allAssets(pageSize: 3, maximumPages: 5)

        indexer.failsPagesWithStatus = 503
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.qualification?.source, .cache)
        XCTAssertEqual(read.value, good)
        // An outage is not retried in a loop: the page that failed is asked
        // for twice more (review round 4), then the walk ends.
        XCTAssertEqual(pageReads(), 1 + PIIndexerClient.maximumTransientRetries)
        XCTAssertEqual(pauses.count, PIIndexerClient.maximumTransientRetries)
    }

    func testWithoutALastGoodCatalogTheFailureIsReported() async throws {
        let indexer = try indexer()
        indexer.indexAge = 600

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A stale indexer produced a catalog")
        } catch {
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            healthReads(),
            1 + PIIndexerClient.maximumStaleCheckpointRetries
        )
    }

    /// Wrong data is never replaced by older data: a response that does not
    /// decode is an error even when a last good catalog exists.
    func testAResponseThatDoesNotDecodeIsNotHiddenByTheLastGoodCatalog()
        async throws
    {
        let indexer = try indexer()
        _ = try await client().allAssets(pageSize: 3, maximumPages: 5)

        indexer.assetRows = [#"{"id":"xor","priceUSD":{"amount":"1"}}"#]
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A malformed catalog was replaced by an older one")
        } catch {
            XCTAssertTrue(error is DecodingError, "\(error)")
        }
    }

    // MARK: Review round 2

    /// The app was suspended after a page arrived and before its postflight
    /// health read. PI is hundreds of blocks further on: the page is not
    /// known to be current at that checkpoint, so the walk starts again.
    func testAPostflightFarAheadOfItsPreflightRestartsTheWalk()
        async throws
    {
        let indexer = try indexer()
        indexer.heightForHealthRead = { read, height in
            // The second health read is page 1's postflight.
            read == 2 ? height + 1_200 : height + 1
        }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(read.qualification?.source, .live)
        XCTAssertEqual(pauses.count, 1)
        // The first walk stopped at its first page.
        XCTAssertEqual(pageReads(), 1 + 3)
    }

    /// Every request stays within its own bound, but the walk as a whole
    /// is spread over more blocks than a healthy read ever needs. It starts
    /// again instead of mixing old first pages with a new checkpoint.
    func testAWalkSpreadOverTooManyBlocksStartsAgain() async throws {
        let indexer = try indexer()
        indexer.heightForHealthRead = { read, height in
            read <= 5 ? height + 18 : height + 1
        }

        let read = try await client().qualifiedAllAssets(
            pageSize: 2,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(pauses.count, 1)
        // Four pages, 54 blocks apart; then four pages again.
        XCTAssertEqual(pageReads(), 4 + 4)
    }

    func testTheForwardRuleIsBounded() throws {
        func health(_ height: Int) throws -> PIHealth {
            struct Payload: Decodable { let _health: PIHealth }
            return try PIIndexerClient.decodeResponse(
                Payload.self,
                from: Data(
                    PIAdvancingIndexer.health(
                        indexed: height,
                        finalized: height + 1,
                        indexedAt: 1_791_700_000
                    ).utf8
                )
            )._health
        }
        let start = try health(1_000)
        let limit = PIIndexerClient.maximumCheckpointAdvancePerRequest

        XCTAssertEqual(
            try PIIndexerClient.settledResponseCheckpoint(
                preflight: start,
                postflight: try health(1_000 + limit)
            ),
            try health(1_000 + limit)
        )
        XCTAssertThrowsError(
            try PIIndexerClient.settledResponseCheckpoint(
                preflight: start,
                postflight: try health(1_001 + limit)
            )
        ) { error in
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let walkLimit = PIIndexerClient.maximumCheckpointAdvancePerWalk
        let first = PIReadQualification(health: start, source: .live)
        XCTAssertNoThrow(
            try PIIndexerClient.validateWalkAdvance(
                first: first,
                current: PIReadQualification(
                    health: try health(1_000 + walkLimit),
                    source: .live
                )
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateWalkAdvance(
                first: first,
                current: PIReadQualification(
                    health: try health(1_001 + walkLimit),
                    source: .live
                )
            )
        )
    }

    /// PI indexed a block between page 1's request and page 1's own
    /// postflight, so page 1 is attributed to the new checkpoint and page 2
    /// reports the same one. The row added in that block changes the
    /// count. That is the indexer moving, not a broken response: the walk
    /// starts again instead of failing.
    func testACountThatChangesWhileOnePageIsReadRestartsTheWalk()
        async throws
    {
        let indexer = try indexer()
        indexer.heightForHealthRead = { read, height in
            read == 2 ? height + 1 : height
        }
        indexer.totalCountForPageRead = { read in read == 2 ? 9 : 8 }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(pauses.count, 1)
        XCTAssertEqual(pageReads(), 2 + 3)
    }

    /// PI restarts for a deploy and reports that its worker has not
    /// finished starting. It is the right service without a usable
    /// checkpoint for the moment: the last good catalog is shown, also on a
    /// cold start.
    func testAnIndexerThatIsRestartingGivesTheLastGoodCatalog()
        async throws
    {
        let indexer = try indexer()
        let good = try await client().allAssets(pageSize: 3, maximumPages: 5)

        indexer.workerStartupComplete = false
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.qualification?.source, .cache)
        XCTAssertEqual(read.value, good)
        // The snapshot says when it was saved, so the store can show its
        // real age.
        let savedAt = try XCTUnwrap(read.savedAt)
        XCTAssertEqual(savedAt.timeIntervalSinceNow, 0, accuracy: 30)
        XCTAssertEqual(pageReads(), 0)
        XCTAssertEqual(
            healthReads(),
            1 + PIIndexerClient.maximumStaleCheckpointRetries
        )
    }

    /// Readiness and identity are different failures: another service is
    /// never treated as "not ready", whatever it says about readiness.
    func testAnotherServiceThatIsNotReadyIsStillAnotherService() throws {
        struct Payload: Decodable { let _health: PIHealth }
        func health(serviceId: String, ready: Bool) throws -> PIHealth {
            try PIIndexerClient.decodeResponse(
                Payload.self,
                from: Data(
                    PIAdvancingIndexer.health(
                        indexed: 1_000,
                        finalized: 1_001,
                        indexedAt: 1_791_700_000,
                        serviceId: serviceId,
                        workerStartupComplete: ready
                    ).utf8
                )
            )._health
        }

        XCTAssertThrowsError(
            try PIIndexerClient.validateHealth(
                try health(serviceId: "other.example", ready: false),
                nowEpochSeconds: 1_791_700_002
            )
        ) { error in
            guard case PIIndexerError.invalidServiceIdentity = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try PIIndexerClient.validateHealth(
                try health(serviceId: "pi.soramitsu.io", ready: false),
                nowEpochSeconds: 1_791_700_002
            )
        ) { error in
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertNoThrow(
            try PIIndexerClient.validateHealth(
                try health(serviceId: "pi.soramitsu.io", ready: true),
                nowEpochSeconds: 1_791_700_002
            )
        )
    }

    func testAnotherIndexerAnsweringMidWalkIsRejected() async throws {
        let indexer = try indexer()
        var reads = 0
        PIStubIndexerProtocol.install { request in
            if request.operation == "MobileHealth" {
                reads += 1
                indexer.serviceId =
                    reads.isMultiple(of: 2) ? "other.example" : "pi.soramitsu.io"
            }
            return indexer.respond(to: request)
        }

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A response from another service was accepted")
        } catch let error as PIIndexerError {
            // The health record of another service is not this indexer.
            switch error {
            case .invalidServiceIdentity, .staleCheckpoint:
                break
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    /// Activity reaches page 2 by walking from page 1. PI indexes a block
    /// between the two pages; the page is attributed to the later
    /// checkpoint.
    func testActivityPageTwoIsReachedWhileTheIndexerAdvances() async throws {
        let account = "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy"
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: PIIndexerFixture.data("history-signer-page")
            ) as? [String: Any]
        )
        let nodes = try XCTUnwrap(
            ((object["data"] as? [String: Any])?["historyElements"]
                as? [String: Any])?["nodes"] as? [[String: Any]]
        )
        let rows = try nodes.map { node in
            String(
                decoding: try JSONSerialization.data(withJSONObject: node),
                as: UTF8.self
            )
        }
        XCTAssertEqual(rows.count, 4)
        let indexer = try indexer()
        indexer.heightForHealthRead = { _, height in height + 1 }
        PIStubIndexerProtocol.install { request in
            guard request.operation == "MobileHistory" else {
                return indexer.respond(to: request)
            }
            let after = request.variables["after"] as? String
            let page = after == nil ? rows[0 ..< 2] : rows[2 ..< 4]
            return .init(
                body: """
                {"data":{"historyElements":{"nodes":[\(page.joined(separator: ","))],\
                "pageInfo":{"hasNextPage":\(after == nil),\
                "hasPreviousPage":\(after != nil),"startCursor":"s",\
                "endCursor":"\(after == nil ? "c2" : "c4")"},"totalCount":4}}}
                """
            )
        }

        let read = try await client().qualifiedHistoryPageWithCoverage(
            address: account,
            first: 2,
            page: 2
        )

        XCTAssertEqual(read.read.value.values.count, 2)
        XCTAssertEqual(read.read.qualification?.source, .live)
        // Two pages cost two page requests and three health requests, and
        // the checkpoint moved three blocks.
        XCTAssertEqual(
            PIStubIndexerProtocol.requests.filter { $0 == "MobileHistory" }.count,
            2
        )
        XCTAssertEqual(healthReads(), 3)
        XCTAssertEqual(
            read.read.qualification?.health.workerLatestIndexedBlock,
            27_992_167
        )
        XCTAssertTrue(pauses.isEmpty)
    }

    // MARK: Device clock

    /// The device clock is two hours behind. PI's timestamps are judged
    /// against the `Date` header PI sent, so prices still load.
    func testADeviceClockThatIsHoursOffStillLoadsPrices() async throws {
        let offsets: [TimeInterval] = [2 * 3_600, -5 * 3_600]
        for offset in offsets {
            let indexer = try indexer()
            indexer.clockOffset = offset

            let read = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )

            XCTAssertEqual(read.value.count, 8, "\(offset)")
            XCTAssertEqual(read.qualification?.source, .live)
        }
    }

    /// The catalog saved on a device with a wrong clock is still usable as
    /// the last good catalog.
    func testLastGoodCatalogSavedWithAWrongDeviceClockIsUsable()
        async throws
    {
        let indexer = try indexer()
        indexer.clockOffset = 2 * 3_600
        let good = try await client().allAssets(pageSize: 3, maximumPages: 5)

        indexer.failsPagesWithStatus = 503
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.qualification?.source, .cache)
        XCTAssertEqual(read.value, good)
    }

    /// Review round 4. The date of this phone was set three days back, or
    /// two days ahead, by hand. TLS still works, and PI's timestamps are
    /// judged by PI's own `Date`, so prices load, and the catalog saved on
    /// that phone serves as the last good one. Before, such a phone showed
    /// "Price unavailable" for as long as its clock was wrong.
    func testADeviceClockThatIsDaysOffStillLoadsPricesAndKeepsItsLastGoodCatalog()
        async throws
    {
        for offset in [-3.0 * 24 * 3_600, 2.0 * 24 * 3_600] {
            let indexer = try indexer()
            indexer.clockOffset = offset

            let good = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTAssertEqual(good.value.count, 8, "\(offset)")
            XCTAssertEqual(good.qualification?.source, .live, "\(offset)")

            indexer.failsPagesWithStatus = 503
            PIStubIndexerProtocol.install { indexer.respond(to: $0) }
            let fallback = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTAssertEqual(fallback.qualification?.source, .cache, "\(offset)")
            XCTAssertEqual(fallback.value, good.value, "\(offset)")
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
    }

    /// The server's clock replaces the device clock; it does not switch the
    /// freshness check off. An indexer whose last block is ten minutes old
    /// by its own clock is refused on a phone with a wrong date too.
    func testAnIndexerThatIsStaleByItsOwnClockIsRefusedWhateverTheDeviceClock()
        async throws
    {
        let indexer = try indexer()
        indexer.clockOffset = -3 * 24 * 3_600
        indexer.indexAge = 600

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("An indexer ten minutes behind its own clock was accepted")
        } catch {
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(pageReads(), 0)
    }

    func testAResponseWithoutADateHeaderUsesTheDeviceClock() async throws {
        let indexer = try indexer()
        PIStubIndexerProtocol.install { request in
            var response = indexer.respond(to: request)
            response.omitsDateHeader = true
            return response
        }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )
        XCTAssertEqual(read.value.count, 8)
    }
}

// MARK: - Shared catalog: single flight, reuse, backoff, last good

final class PICatalogStoreTests: XCTestCase {
    private final class Source {
        private let lock = NSLock()
        private var calls = 0
        private var uptime: TimeInterval = 1_000
        var result: Result<PIQualifiedRead<[String]>, Swift.Error> =
            .success(PIQualifiedRead(value: ["a"], qualification: nil))
        var delayNanoseconds: UInt64 = 0
        /// What an earlier run saved on disk.
        var saved: PIQualifiedRead<[String]>?
        private var savedReads = 0
        private var held = false
        private var waiting: [CheckedContinuation<Void, Never>] = []

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }

        var savedReadCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return savedReads
        }

        /// From now on a read does not end until `release()`: PI is slow,
        /// or the request is waiting for a connection.
        func hold() {
            lock.lock()
            held = true
            lock.unlock()
        }

        /// Ends the reads that are held, with the `result` of this moment.
        func release() {
            lock.lock()
            held = false
            let resumed = waiting
            waiting = []
            lock.unlock()
            resumed.forEach { $0.resume() }
        }

        private func park(_ continuation: CheckedContinuation<Void, Never>) {
            lock.lock()
            if held {
                waiting.append(continuation)
                lock.unlock()
            } else {
                lock.unlock()
                continuation.resume()
            }
        }

        private func countCall() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            calls += 1
            return delayNanoseconds
        }

        private func currentResult()
            -> Result<PIQualifiedRead<[String]>, Swift.Error>
        {
            lock.lock()
            defer { lock.unlock() }
            return result
        }

        func readSaved() -> PIQualifiedRead<[String]>? {
            lock.lock()
            defer { lock.unlock() }
            savedReads += 1
            return saved
        }

        var now: TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return uptime
        }

        func advance(_ seconds: TimeInterval) {
            lock.lock()
            uptime += seconds
            lock.unlock()
        }

        func load() async throws -> PIQualifiedRead<[String]> {
            let delay = countCall()
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            await withCheckedContinuation { park($0) }
            return try currentResult().get()
        }
    }

    /// Runs `snapshot()` and fails, instead of hanging, when it has not
    /// returned after five seconds: the call was waiting for a read.
    private func withoutWaiting(
        _ store: PICatalogStore<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> PICatalogSnapshot<String>? {
        let returned = expectation(description: "snapshot() returned")
        let call = Task { () -> PICatalogSnapshot<String>? in
            let snapshot = try? await store.snapshot()
            returned.fulfill()
            return snapshot
        }
        let outcome = await XCTWaiter().fulfillment(
            of: [returned],
            timeout: 5
        )
        guard outcome == .completed else {
            XCTFail(
                "The caller was kept waiting for the read",
                file: file,
                line: line
            )
            return nil
        }
        return await call.value
    }

    /// The wall clock that goes with `Source.now`: second 1000 of the
    /// test's uptime is this moment.
    private static let wallClockStart = Date(timeIntervalSince1970: 1_791_700_000)

    private func wallClock(_ source: Source) -> Date {
        Self.wallClockStart.addingTimeInterval(source.now - 1_000)
    }

    private func store(
        _ source: Source,
        freshFor: TimeInterval = 600,
        staleFor: TimeInterval? = nil,
        lastGoodFor: TimeInterval = 24 * 3_600,
        onChange: (() -> Void)? = nil
    ) -> PICatalogStore<String> {
        PICatalogStore(
            freshFor: freshFor,
            staleFor: staleFor,
            lastGoodFor: lastGoodFor,
            retryDelays: [15, 30, 60],
            uptime: { source.now },
            wallClock: { [unowned self] in self.wallClock(source) },
            onChange: onChange,
            saved: { source.readSaved() },
            load: { try await source.load() }
        )
    }

    private func cached(
        _ values: [String],
        savedAt: Date? = nil
    ) -> PIQualifiedRead<[String]> {
        let now = Int(Date().timeIntervalSince1970)
        return PIQualifiedRead(
            value: values,
            qualification: PIReadQualification(
                health: PIHealth(
                    ok: true,
                    repositoryReady: true,
                    service: "polkaswap-indexer",
                    serviceId: "pi.soramitsu.io",
                    schemaVersion: 1,
                    ecosystem: "sora2",
                    chainId: "sora:mainnet",
                    network: "mainnet",
                    publicBaseUrl: PIIndexerClient.endpoint,
                    readOnly: true,
                    genesisHash: nil,
                    latestIndexedBlock: nil,
                    latestIndexedBlockHash: nil,
                    latestIndexedAt: nil,
                    workerAvailable: true,
                    workerReady: true,
                    workerReadinessReason: nil,
                    workerLifecycle: "running",
                    workerStartupComplete: true,
                    workerLatestFinalizedBlock: 100,
                    workerLatestIndexedBlock: 100,
                    workerLag: 0,
                    workerLastSuccessfulIndexTimestamp: now,
                    workerLastError: nil,
                    workerLastErrorTimestamp: nil
                ),
                source: .cache
            ),
            savedAt: savedAt
        )
    }

    /// Opening the wallet asks for prices from several screens at once.
    /// They share one walk of PI.
    func testConcurrentCallersShareOneRead() async throws {
        let source = Source()
        source.delayNanoseconds = 150_000_000
        let store = store(source)

        let results = try await withThrowingTaskGroup(
            of: [String].self
        ) { group -> [[String]] in
            for _ in 0 ..< 12 {
                group.addTask { try await store.values() }
            }
            var all: [[String]] = []
            for try await value in group {
                all.append(value)
            }
            return all
        }

        XCTAssertEqual(results.count, 12)
        XCTAssertTrue(results.allSatisfy { $0 == ["a"] })
        XCTAssertEqual(source.callCount, 1)
    }

    func testALiveCatalogIsReusedWhileFreshThenReadAgain() async throws {
        let source = Source()
        let store = store(source, freshFor: 600)

        _ = try await store.values()
        source.advance(599)
        _ = try await store.values()
        XCTAssertEqual(source.callCount, 1)

        source.result = .success(
            PIQualifiedRead(value: ["b"], qualification: nil)
        )
        source.advance(2)
        // No longer fresh: a read starts, and replaces what is shown.
        _ = try await store.values()
        await store.settled()
        let refreshed = try await store.values()
        XCTAssertEqual(refreshed, ["b"])
        XCTAssertEqual(source.callCount, 2)
    }

    /// A failed read is not repeated on every screen visit: the next one
    /// waits 15 s, then 30 s, then 60 s.
    func testAFailedReadIsNotRepeatedBeforeItsBackoffHasPassed() async {
        let source = Source()
        source.result = .failure(PIIndexerError.httpStatus(503))
        let store = store(source)

        for _ in 0 ..< 50 {
            _ = try? await store.values()
        }
        XCTAssertEqual(source.callCount, 1)

        source.advance(14)
        _ = try? await store.values()
        XCTAssertEqual(source.callCount, 1)
        source.advance(2)
        _ = try? await store.values()
        XCTAssertEqual(source.callCount, 2)

        // The second failure waits twice as long.
        source.advance(29)
        _ = try? await store.values()
        XCTAssertEqual(source.callCount, 2)
        source.advance(2)
        _ = try? await store.values()
        XCTAssertEqual(source.callCount, 3)

        // The delay stops growing at the last step.
        source.advance(61)
        _ = try? await store.values()
        source.advance(61)
        _ = try? await store.values()
        XCTAssertEqual(source.callCount, 5)

        do {
            _ = try await store.values()
            XCTFail("A store with nothing to show returned a value")
        } catch {
            guard case PIIndexerError.httpStatus(503) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAFailedRefreshShowsTheLastGoodCatalogAndRecovers() async throws {
        let source = Source()
        let store = store(source, freshFor: 600)
        _ = try await store.values()

        source.advance(601)
        source.result = .failure(PIIndexerError.staleCheckpoint)
        let duringOutage = try await store.values()
        XCTAssertEqual(duringOutage, ["a"])
        await store.settled()
        XCTAssertEqual(source.callCount, 2)
        // No new request while backing off; the last good catalog is shown.
        let again = try await store.values()
        XCTAssertEqual(again, ["a"])
        XCTAssertEqual(source.callCount, 2)

        source.advance(16)
        source.result = .success(
            PIQualifiedRead(value: ["b"], qualification: nil)
        )
        // The backoff has passed. PI has been failing, so the caller is
        // not kept waiting for the new attempt: it gets the last good
        // catalog at once and the read runs behind it.
        let whileRetrying = try await store.snapshot()
        XCTAssertEqual(whileRetrying.values, ["a"])
        XCTAssertNotNil(whileRetrying.asOf)
        await store.settled()
        let recovered = try await store.snapshot()
        XCTAssertEqual(recovered.values, ["b"])
        XCTAssertNil(recovered.asOf)
        XCTAssertEqual(source.callCount, 3)
        // A success clears the backoff.
        source.advance(601)
        source.result = .failure(PIIndexerError.staleCheckpoint)
        _ = try await store.values()
        await store.settled()
        source.advance(16)
        _ = try await store.values()
        await store.settled()
        XCTAssertEqual(source.callCount, 5)
    }

    /// The client could only give its saved last good catalog: show it, and
    /// keep trying on the failure schedule instead of treating it as fresh.
    func testACatalogFromTheClientsLastGoodCopyKeepsRetrying() async throws {
        let source = Source()
        source.result = .success(cached(["saved"]))
        let store = store(source, freshFor: 600)

        let first = try await store.values()
        XCTAssertEqual(first, ["saved"])
        let second = try await store.values()
        XCTAssertEqual(second, ["saved"])
        XCTAssertEqual(source.callCount, 1)

        source.advance(16)
        source.result = .success(
            PIQualifiedRead(value: ["live"], qualification: nil)
        )
        // Shown at once from the saved copy; the live read replaces it.
        let meanwhile = try await store.values()
        XCTAssertEqual(meanwhile, ["saved"])
        await store.settled()
        let live = try await store.values()
        XCTAssertEqual(live, ["live"])
        XCTAssertEqual(source.callCount, 2)
    }

    // MARK: Review round 2: sleep, real age, refresh in the background

    /// Prices were loaded at 09:00 and the phone was locked until 12:00.
    /// The store's clock counts that time, so the catalog is not served as
    /// current: the caller gets it marked with 09:00, a new read starts at
    /// once, and its result replaces the old prices.
    func testACatalogLoadedBeforeTheDeviceSleptIsReadAgain() async throws {
        let source = Source()
        let store = store(source, freshFor: 600, staleFor: 1_800)
        let loadedAt = wallClock(source)
        let morning = try await store.values()
        XCTAssertEqual(morning, ["a"])

        source.advance(3 * 3_600)
        source.result = .success(
            PIQualifiedRead(value: ["noon"], qualification: nil)
        )
        let onUnlock = try await store.snapshot()
        XCTAssertEqual(onUnlock.values, ["a"])
        XCTAssertEqual(onUnlock.asOf, loadedAt)

        await store.settled()
        let noon = try await store.snapshot()
        XCTAssertEqual(noon.values, ["noon"])
        XCTAssertNil(noon.asOf)
        XCTAssertEqual(source.callCount, 2)
    }

    /// The store's own clock is the one that keeps counting while the
    /// device sleeps (`mach_continuous_time`), not `systemUptime`, which
    /// stops. The two differ on any host that has slept since boot.
    func testTheDefaultClockCountsTheTimeTheDeviceSleeps() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let continuous = TimeInterval(mach_continuous_time()) *
            TimeInterval(timebase.numer) / TimeInterval(timebase.denom) /
            1_000_000_000
        let clock = PICatalogStore<String>.continuousUptime()

        XCTAssertEqual(clock, continuous, accuracy: 1)
        XCTAssertGreaterThanOrEqual(
            clock,
            ProcessInfo.processInfo.systemUptime - 1
        )
    }

    /// A backoff reached while offline must not still be running when the
    /// app is opened again: coming to the foreground clears it.
    func testReturningToTheForegroundClearsTheBackoff() async throws {
        let source = Source()
        source.result = .failure(URLError(.notConnectedToInternet))
        let store = store(source)
        _ = try? await store.values()
        _ = try? await store.values()
        XCTAssertEqual(source.callCount, 1)

        source.result = .success(
            PIQualifiedRead(value: ["a"], qualification: nil)
        )
        await store.clearBackoff()
        let values = try await store.values()

        XCTAssertEqual(values, ["a"])
        XCTAssertEqual(source.callCount, 2)
    }

    /// A snapshot that was 23 hours old when it was read from disk is not
    /// given another 24 hours: its real age counts.
    func testASnapshotFromDiskKeepsItsRealAge() async throws {
        let source = Source()
        let savedAt = wallClock(source).addingTimeInterval(-23 * 3_600)
        source.result = .success(cached(["saved"], savedAt: savedAt))
        let store = store(source, lastGoodFor: 24 * 3_600)

        let first = try await store.snapshot()
        XCTAssertEqual(first.values, ["saved"])
        XCTAssertEqual(first.asOf, savedAt)

        // Two hours later PI still cannot be read and the client has no
        // snapshot young enough any more.
        source.advance(2 * 3_600)
        source.result = .failure(PIIndexerError.httpStatus(503))
        do {
            _ = try await store.snapshot()
            XCTFail("A 25-hour-old catalog was shown")
        } catch {
            guard case PIIndexerError.httpStatus(503) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    /// Older data stands in for PI only when PI cannot be read. Once PI
    /// has answered with a response that does not decode (the 10 October
    /// failure) or fails validation, that is an error: the prices from
    /// before are no longer shown, not even while the next read is on its
    /// way or after a return to the foreground.
    func testAResponseThatCannotBeUsedIsNotReplacedByTheLastGoodCatalog()
        async throws
    {
        let source = Source()
        let store = store(source, freshFor: 600)
        let loadedAt = wallClock(source)
        _ = try await store.values()

        source.advance(601)
        source.result = .failure(
            DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "volumeDayUSD")
            )
        )
        // The read has only started: what is held is shown with its time.
        let meanwhile = try await store.snapshot()
        XCTAssertEqual(meanwhile.values, ["a"])
        XCTAssertEqual(meanwhile.asOf, loadedAt)
        await store.settled()

        do {
            _ = try await store.values()
            XCTFail("A catalog that failed to decode was replaced")
        } catch {
            XCTAssertTrue(error is DecodingError, "\(error)")
        }
        XCTAssertEqual(source.callCount, 2)

        // The next read: the caller waits for it and is not shown the
        // older catalog meanwhile.
        source.result = .failure(PIIndexerError.invalidServiceIdentity)
        source.advance(16)
        do {
            _ = try await store.values()
            XCTFail("Another service's answer was replaced by older data")
        } catch {
            guard case PIIndexerError.invalidServiceIdentity = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(source.callCount, 3)

        // Coming back to the foreground starts a read at once, and still
        // does not bring the older catalog back.
        source.result = .failure(
            DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "volumeDayUSD")
            )
        )
        await store.clearBackoff()
        do {
            _ = try await store.values()
            XCTFail("The older catalog came back with the foreground")
        } catch {
            XCTAssertTrue(error is DecodingError, "\(error)")
        }
        XCTAssertEqual(source.callCount, 4)

        // PI can be read again: the new catalog is shown.
        source.result = .success(
            PIQualifiedRead(value: ["b"], qualification: nil)
        )
        source.advance(16)
        let recovered = try await store.snapshot()
        XCTAssertEqual(recovered.values, ["b"])
        XCTAssertNil(recovered.asOf)
    }

    /// A caller is not kept waiting for a refresh when the catalog it can
    /// have is only a little old: it gets that at once, the refresh runs
    /// behind it and announces itself.
    func testARecentCatalogIsServedAtOnceWhileItsRefreshRuns() async throws {
        let source = Source()
        let changes = Counter()
        let store = store(
            source,
            freshFor: 600,
            staleFor: 1_800,
            onChange: { changes.increment() }
        )
        _ = try await store.values()
        XCTAssertEqual(changes.value, 1)

        source.advance(700)
        // The refresh does not end until the test lets it, so "at once" is
        // checked without a stopwatch.
        source.hold()
        source.result = .success(
            PIQualifiedRead(value: ["b"], qualification: nil)
        )
        let atOnce = await withoutWaiting(store)
        XCTAssertEqual(atOnce?.values, ["a"])
        XCTAssertEqual(atOnce.map { $0.asOf == nil }, true)
        // A second caller neither waits nor starts a second read.
        let second = await withoutWaiting(store)
        XCTAssertEqual(second?.values, ["a"])

        source.release()
        await store.settled()
        XCTAssertEqual(changes.value, 2)
        let refreshed = try await store.values()
        XCTAssertEqual(refreshed, ["b"])
        XCTAssertEqual(source.callCount, 2)
    }

    /// Prices shown while PI cannot be read carry the time they date from.
    func testOldPricesAreMarkedWithTheTimeTheyDateFrom() async throws {
        let source = Source()
        let store = store(source, freshFor: 600, staleFor: 1_800)
        let loadedAt = wallClock(source)
        let live = try await store.snapshot()
        XCTAssertNil(live.asOf)

        source.advance(900)
        source.result = .failure(URLError(.timedOut))
        // Served at once, still unmarked: nothing has failed yet.
        let recent = try await store.snapshot()
        XCTAssertNil(recent.asOf)
        await store.settled()

        let afterFailure = try await store.snapshot()
        XCTAssertEqual(afterFailure.values, ["a"])
        XCTAssertEqual(afterFailure.asOf, loadedAt)
    }
}

/// A thread-safe counter for callbacks.
final class Counter {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

extension PICatalogStoreTests {
    func testCounterStartsAtZero() {
        XCTAssertEqual(Counter().value, 0)
    }

    func testTheLastGoodCatalogIsNotShownForever() async throws {
        let source = Source()
        let store = store(source, freshFor: 600, lastGoodFor: 3_600)
        _ = try await store.values()

        source.result = .failure(PIIndexerError.httpStatus(503))
        source.advance(3_601)
        do {
            _ = try await store.values()
            XCTFail("A catalog older than the last-good limit was shown")
        } catch {
            guard case PIIndexerError.httpStatus(503) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - A failed price load is not a zero balance

final class WalletFiatTotalTests: XCTestCase {
    private let xor =
        "0x0200000000000000000000000000000000000000000000000000000000000000"

    private func balances() -> [BalanceData] {
        [
            BalanceData(
                identifier: xor,
                balance: AmountDecimal(value: Decimal(string: "12.5")!)
            ),
        ]
    }

    func testWalletTotalWithoutPricesIsANoticeNotZero() throws {
        let text = AssetsItemService.fiatTotalText(
            balances: balances(),
            fiatData: []
        )

        XCTAssertEqual(text, WalletUX.priceUnavailableText)
        XCTAssertFalse(text.contains("0"))
        XCTAssertFalse(text.contains("$"))
        XCTAssertFalse(text.isEmpty)
    }

    func testWalletTotalWithPricesIsTheSum() throws {
        let prices = [
            PIExactFiatData(id: xor, priceUsd: try PIQuantity("2")),
        ]

        XCTAssertEqual(
            AssetsItemService.fiatTotalText(
                balances: balances(),
                fiatData: prices
            ),
            "$25"
        )
        // With prices, an empty wallet really is worth nothing.
        XCTAssertEqual(
            AssetsItemService.fiatTotalText(balances: [], fiatData: prices),
            "$0"
        )
        XCTAssertEqual(
            WalletUX.fiatTotalText(0, pricesAvailable: true),
            "$0"
        )
    }

    func testFiatServiceReportsNoPricesWhenTheCatalogCannotBeRead() async {
        let failing = FiatService(assets: {
            throw PIIndexerError.staleCheckpoint
        })
        let prices = await failing.getFiat()
        XCTAssertTrue(prices.isEmpty)
        XCTAssertEqual(
            AssetsItemService.fiatTotalText(
                balances: balances(),
                fiatData: prices
            ),
            WalletUX.priceUnavailableText
        )
    }

    func testPriceUnavailableNoticeIsCalmAndTranslated() {
        XCTAssertEqual(
            WalletUX.text("Price unavailable", language: "en"),
            "Price unavailable"
        )
        XCTAssertEqual(
            WalletUX.text("Price unavailable", language: "ja"),
            "価格を取得できません"
        )
        for language in ["en", "ja"] {
            let text = WalletUX.text("Price unavailable", language: language)
            XCTAssertFalse(text.lowercased().contains("error"))
            XCTAssertFalse(text.contains("!"))
        }
    }

    func testPriceRetryDelayGrowsAndIsCapped() {
        XCTAssertEqual(WalletUX.priceRetryDelay(afterFailures: 0), 20)
        XCTAssertEqual(WalletUX.priceRetryDelay(afterFailures: 1), 40)
        XCTAssertEqual(WalletUX.priceRetryDelay(afterFailures: 3), 160)
        XCTAssertEqual(WalletUX.priceRetryDelay(afterFailures: 4), 300)
        XCTAssertEqual(WalletUX.priceRetryDelay(afterFailures: 400), 300)
        XCTAssertEqual(WalletUX.priceRetryDelay(afterFailures: -1), 20)
    }
}

// MARK: - No screen shows "$0" for an unknown price (review round 2)

private let priceTestXor =
    "0x0200000000000000000000000000000000000000000000000000000000000000"
private let priceTestVal =
    "0x0200040000000000000000000000000000000000000000000000000000000000"

private final class PriceTestAssetManager: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []

    let assets: [AssetInfo]

    init(assets: [AssetInfo]) {
        self.assets = assets
    }

    func assetInfo(for identifier: String) -> AssetInfo? {
        assets.first { $0.assetId == identifier }
    }

    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_: [AssetInfo]) {}
    func saveAssetList(_: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible _: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for _: SelectedWalletSettings) {}
}

private final class PriceTestAssetProvider: AssetProviderProtocol {
    var balances: [BalanceData]
    /// Assets whose balance could not be read.
    var unavailable: Set<String>

    init(balances: [BalanceData], unavailable: Set<String> = []) {
        self.balances = balances
        self.unavailable = unavailable
    }

    func getBalances(with assetIds: [String]) -> [BalanceData] {
        balances.filter { assetIds.contains($0.identifier) }
    }

    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
        unavailable.intersection(assetIds)
    }

    func add(observer _: AssetProviderObserverProtocol) {}
    func remove(observer _: AssetProviderObserverProtocol) {}
}

private final class PriceTestMarketCap: MarketCapServiceProtocol {
    func getMarketCap(for _: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class PriceTestPriceInfo: PriceInfoServiceProtocol {
    private let lock = NSLock()
    private var current = PriceInfo(fiatData: [], marketCapInfo: [])
    private var count = 0

    var info: PriceInfo {
        get {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
        set {
            lock.lock()
            current = newValue
            lock.unlock()
        }
    }

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func getPriceInfo(for _: [String]) async -> PriceInfo {
        lock.lock()
        count += 1
        let info = current
        lock.unlock()
        return info
    }
}

private final class PriceTestSendingViewModel: ConfirmSendingViewModelProtocol {
    func networkFeeInfoButtonTapped() {}
}

private final class PriceTestExplorePools: ExplorePoolsServiceInputProtocol {
    private let lock = NSLock()
    private var count = 0

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func getPools(with _: [PIExactFiatData]) async throws -> [ExplorePool] {
        lock.lock()
        count += 1
        lock.unlock()
        return []
    }
}

private actor PriceTestAPY: APYServiceProtocol {
    func getApy(for _: String, targetAssetId _: String) async -> Decimal? { nil }
    func setup(factory _: PolkaswapNetworkOperationFactoryProtocol) {}
}

final class PIPriceDisplayTests: XCTestCase {
    private func assets() -> [AssetInfo] {
        [
            AssetInfo(id: priceTestXor, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: priceTestVal, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "SORA Validator Token", visible: true),
        ]
    }

    private func balances() -> [BalanceData] {
        [
            BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: Decimal(string: "12.5")!)),
            BalanceData(identifier: priceTestVal, balance: AmountDecimal(value: Decimal(3))),
        ]
    }

    private func walletService(
        _ prices: PriceTestPriceInfo
    ) -> AssetsItemService {
        let manager = PriceTestAssetManager(assets: assets())
        return AssetsItemService(
            marketCapService: PriceTestMarketCap(),
            fiatService: nil,
            assetViewModelsFactory: AssetViewModelFactory(
                walletAssets: assets(),
                assetManager: manager,
                fiatService: nil
            ),
            assetManager: manager,
            assetProvider: PriceTestAssetProvider(balances: balances()),
            priceInfoService: prices
        )
    }

    private func wait(
        _ what: String,
        until condition: @escaping () -> Bool
    ) async {
        for _ in 0 ..< 400 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    /// The wallet through its production service: no prices gives the
    /// notice, rows without a placeholder that never ends, and a retry;
    /// prices give the total and end the retry.
    func testWalletShowsTheNoticeThenTheTotal() async throws {
        let prices = PriceTestPriceInfo()
        let service = walletService(prices)

        service.setup()
        await wait("the notice") { !service.moneyText.isEmpty }

        XCTAssertEqual(service.moneyText, WalletUX.priceUnavailableText)
        XCTAssertTrue(service.priceIsUnavailable)
        XCTAssertEqual(service.priceNoteText, "")
        XCTAssertTrue(service.hasScheduledPriceRetry)
        XCTAssertEqual(service.assetViewModels.count, 2)
        for row in service.assetViewModels {
            XCTAssertEqual(row.fiatText, "")
            XCTAssertTrue(row.priceLoadFinished)
        }

        prices.info = PriceInfo(
            fiatData: [
                PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("2")),
            ],
            marketCapInfo: []
        )
        service.setup()
        await wait("the total") { service.moneyText == "$25" }

        XCTAssertFalse(service.priceIsUnavailable)
        XCTAssertEqual(service.priceNoteText, "")
        XCTAssertFalse(service.hasScheduledPriceRetry)
        let xor = try XCTUnwrap(
            service.assetViewModels.first { $0.identifier == priceTestXor }
        )
        XCTAssertEqual(xor.fiatText, "$25")
        // VAL has no price in the catalog: no value, and no placeholder.
        let val = try XCTUnwrap(
            service.assetViewModels.first { $0.identifier == priceTestVal }
        )
        XCTAssertEqual(val.fiatText, "")
        XCTAssertTrue(val.priceLoadFinished)
    }

    /// Prices from the last good catalog are marked with their time, and
    /// the wallet keeps asking for current ones.
    func testWalletMarksOldPricesWithTheirTime() async throws {
        let asOf = Date(timeIntervalSinceNow: -3 * 3_600)
        let prices = PriceTestPriceInfo()
        prices.info = PriceInfo(
            fiatData: [
                PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("2")),
            ],
            marketCapInfo: [],
            pricesAsOf: asOf
        )
        let service = walletService(prices)

        service.setup()
        await wait("the total") { service.moneyText == "$25" }

        XCTAssertEqual(service.priceNoteText, WalletUX.pricesAsOfText(asOf))
        XCTAssertFalse(service.priceNoteText.isEmpty)
        XCTAssertFalse(service.priceIsUnavailable)
        XCTAssertTrue(service.hasScheduledPriceRetry)
    }

    /// A background refresh or a return to the foreground announces itself;
    /// the wallet then values itself again without any action by the user.
    func testWalletAsksAgainWhenPricesChange() async throws {
        let prices = PriceTestPriceInfo()
        let service = walletService(prices)
        service.setup()
        await wait("the first read") { prices.calls == 1 }

        NotificationCenter.default.post(
            name: PICatalogs.pricesDidChange,
            object: nil
        )

        await wait("the second read") { prices.calls == 2 }
        _ = service
    }

    private func visibleLabelTexts(in view: UIView) -> [String] {
        guard !view.isHidden else { return [] }
        var texts: [String] = []
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            texts.append(text)
        }
        for subview in view.subviews {
            texts.append(contentsOf: visibleLabelTexts(in: subview))
        }
        return texts
    }

    /// Writes the cell as a PNG when `TEST_RUNNER_SORA_RENDER_DIR` names a
    /// directory, so the states can be looked at without a running wallet.
    @MainActor
    private func render(_ cell: UITableViewCell, name: String) {
        guard
            let directory = ProcessInfo.processInfo.environment["SORA_RENDER_DIR"],
            !directory.isEmpty
        else { return }
        let width: CGFloat = 393
        let height = cell.contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        cell.frame = CGRect(x: 0, y: 0, width: width, height: max(height, 120))
        cell.backgroundColor = WalletUX.page
        cell.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: cell.bounds).image { context in
            cell.layer.render(in: context.cgContext)
        }
        let url = URL(fileURLWithPath: directory)
            .appendingPathComponent(name + ".png")
        try? image.pngData()?.write(to: url)
    }

    /// The wallet's "Liquid assets" card itself, with the production cell:
    /// the notice instead of a total; then a total with the time of the
    /// old prices under it; then a total alone.
    @MainActor
    func testWalletCardShowsTheNoticeTheTimeOfOldPricesAndTheTotal()
        async throws
    {
        let prices = PriceTestPriceInfo()
        let service = walletService(prices)
        let item = AssetsItem(
            title: "Liquid assets",
            assetProvider: PriceTestAssetProvider(balances: balances()),
            service: service
        )
        let cell = AssetsCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 393, height: 400)
        cell.set(item: item, context: nil)

        func settle() async throws {
            // The cell listens on the main queue.
            try await Task.sleep(nanoseconds: 200_000_000)
            cell.layoutIfNeeded()
        }

        // 1. PI cannot be read and nothing is saved.
        service.setup()
        await wait("the notice") {
            service.moneyText == WalletUX.priceUnavailableText
        }
        try await settle()
        var texts = visibleLabelTexts(in: cell)
        XCTAssertTrue(texts.contains(WalletUX.priceUnavailableText), "\(texts)")
        XCTAssertFalse(texts.contains { $0.contains("$") }, "\(texts)")
        XCTAssertTrue(texts.contains { $0.contains("12.5") }, "\(texts)")
        render(cell, name: "wallet-1-price-unavailable")

        // 2. PI cannot be read; the last good prices are three hours old.
        let asOf = Date(timeIntervalSinceNow: -3 * 3_600)
        let fiatData = [
            PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("2")),
        ]
        prices.info = PriceInfo(
            fiatData: fiatData,
            marketCapInfo: [MarketCapInfo(assetId: priceTestXor, hourDelta: 1.5)],
            pricesAsOf: asOf
        )
        service.setup()
        await wait("the total") { service.moneyText == "$25" }
        try await settle()
        texts = visibleLabelTexts(in: cell)
        XCTAssertTrue(texts.contains("$25"), "\(texts)")
        XCTAssertTrue(texts.contains(WalletUX.pricesAsOfText(asOf)), "\(texts)")
        XCTAssertFalse(texts.contains(WalletUX.priceUnavailableText), "\(texts)")
        render(cell, name: "wallet-2-prices-as-of")

        // 3. Current prices: the total alone.
        prices.info = PriceInfo(
            fiatData: fiatData,
            marketCapInfo: [MarketCapInfo(assetId: priceTestXor, hourDelta: 1.5)]
        )
        service.setup()
        await wait("the note to go") { service.priceNoteText.isEmpty }
        try await settle()
        texts = visibleLabelTexts(in: cell)
        XCTAssertTrue(texts.contains("$25"), "\(texts)")
        XCTAssertFalse(texts.contains { $0.hasPrefix("Prices as of") }, "\(texts)")
        render(cell, name: "wallet-3-current")
        _ = item
    }

    func testFiatServiceCarriesTheTimeOfOldPrices() async throws {
        let asOf = Date(timeIntervalSince1970: 1_791_700_000)
        let old = FiatService(catalog: {
            PICatalogSnapshot(
                values: [
                    PIAsset(
                        id: priceTestXor,
                        priceUSD: try PIQuantity("2"),
                        liquidity: nil,
                        priceChangeDay: nil
                    ),
                ],
                asOf: asOf
            )
        })
        let snapshot = await old.getFiatSnapshot()
        XCTAssertEqual(snapshot.data.count, 1)
        XCTAssertEqual(snapshot.asOf, asOf)

        let failing = FiatService(catalog: {
            throw URLError(.notConnectedToInternet)
        })
        let none = await failing.getFiatSnapshot()
        XCTAssertTrue(none.data.isEmpty)
        XCTAssertNil(none.asOf)
    }

    func testPricesAsOfTextSaysWhenInEnglishAndJapanese() throws {
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        // 11 October 2026, 09:02 UTC.
        let date = Date(timeIntervalSince1970: 1_791_709_320)
        let sameDay = date.addingTimeInterval(3 * 3_600)
        let nextDay = date.addingTimeInterval(20 * 3_600)

        let english = WalletUX.pricesAsOfText(
            date, now: sameDay, language: "en", timeZone: utc
        )
        XCTAssertTrue(english.hasPrefix("Prices as of "), english)
        XCTAssertTrue(english.contains("9:02"), english)
        XCTAssertFalse(english.contains("Oct"), english)

        let japanese = WalletUX.pricesAsOfText(
            date, now: sameDay, language: "ja", timeZone: utc
        )
        XCTAssertTrue(japanese.hasSuffix(" 時点の価格"), japanese)
        XCTAssertTrue(japanese.contains("9:02"), japanese)

        // Not today: the date is part of the text.
        let dated = WalletUX.pricesAsOfText(
            date, now: nextDay, language: "en", timeZone: utc
        )
        XCTAssertTrue(dated.contains("Oct"), dated)
        XCTAssertTrue(dated.contains("9:02"), dated)
    }

    /// Asset Details: the price, the value of the holding and the frozen
    /// value. Without a price none of them reads "$0".
    func testAssetDetailsShowsNoZeroForAnUnknownPrice() {
        XCTAssertEqual(
            AssetDetailsItemFactory.priceText(usdPrice: nil, pricesLoaded: true),
            WalletUX.priceUnavailableText
        )
        // Still loading: blank, not the notice and not a number.
        XCTAssertEqual(
            AssetDetailsItemFactory.priceText(usdPrice: nil, pricesLoaded: false),
            ""
        )
        XCTAssertEqual(
            AssetDetailsItemFactory.priceText(usdPrice: Decimal(string: "5.4"), pricesLoaded: true),
            "$5.4"
        )

        XCTAssertEqual(WalletUX.balanceFiatText(amount: 500, price: nil), "")
        XCTAssertEqual(WalletUX.balanceFiatText(amount: 500, price: 2), "$1,000")
        // A real zero is still a zero.
        XCTAssertEqual(WalletUX.balanceFiatText(amount: 0, price: 2), "$0")
        XCTAssertEqual(WalletUX.fiatText(amount: 500, price: nil), "")
        XCTAssertEqual(WalletUX.fiatText(amount: 500, price: nil, prefix: "~$"), "")
        XCTAssertEqual(WalletUX.fiatText(amount: 500, price: 2, prefix: "~$"), "~$1,000")
    }

    /// The network fee row of the send confirmation, through the
    /// production factory: "0.0007 XOR" and no fiat text, not "$0".
    func testNetworkFeeRowHasNoFiatTextWithoutAPrice() throws {
        let factory = DetailViewModelFactory(
            assetManager: PriceTestAssetManager(assets: assets())
        )
        let viewModel = PriceTestSendingViewModel()
        let fee = try XCTUnwrap(Decimal(string: "0.0007"))

        let unknown = try XCTUnwrap(
            factory.createSendingAssetViewModels(
                fee: fee,
                fiatData: [],
                viewModel: viewModel
            ).first
        )
        XCTAssertEqual(unknown.fiatAmountText?.attributedString.string, "")
        XCTAssertTrue(
            unknown.assetAmountText.attributedString.string.contains("0.0007")
        )

        let known = try XCTUnwrap(
            factory.createSendingAssetViewModels(
                fee: fee,
                fiatData: [
                    PIExactFiatData(
                        id: priceTestXor,
                        priceUsd: try PIQuantity("1000")
                    ),
                ],
                viewModel: viewModel
            ).first
        )
        XCTAssertEqual(known.fiatAmountText?.attributedString.string, "$0.7")
    }

    /// Explore, currencies: without any price every row shows no price;
    /// with prices an asset that has none shows neither a price nor a
    /// market cap.
    func testExploreAssetsShowNoZeroForAnUnknownPrice() async throws {
        let manager = PriceTestAssetManager(assets: assets())
        let prices = PriceTestPriceInfo()
        let service = ExploreAssetViewModelService(
            marketCapService: PriceTestMarketCap(),
            fiatService: nil,
            itemFactory: ExploreItemFactory(assetManager: manager),
            assetInfos: assets(),
            priceInfoService: prices
        )

        let withoutPrices = await service.setup()
        XCTAssertEqual(withoutPrices.count, 2)
        for row in withoutPrices {
            XCTAssertEqual(row.price, "")
            XCTAssertNil(row.marketCap.value)
        }

        prices.info = PriceInfo(
            fiatData: [
                PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("2")),
                PIExactFiatData(id: priceTestVal, priceUsd: nil),
            ],
            marketCapInfo: [
                MarketCapInfo(assetId: priceTestXor, hourDelta: 1, liquidity: 100),
                MarketCapInfo(assetId: priceTestVal, hourDelta: 1, liquidity: 100),
            ]
        )
        let withPrices = await service.setup()
        let xor = try XCTUnwrap(withPrices.first { $0.assetId == priceTestXor })
        XCTAssertEqual(xor.price, "$2")
        XCTAssertEqual(xor.marketCap.value, "$" + Decimal(200).formatNumber())
        let val = try XCTUnwrap(withPrices.first { $0.assetId == priceTestVal })
        XCTAssertEqual(val.price, "")
        XCTAssertNil(val.marketCap.value)
        // The priced asset is listed first.
        XCTAssertEqual(withPrices.first?.assetId, priceTestXor)
    }

    /// Explore, pools: a pool valued without a price shows no TVL, and its
    /// loading placeholder ends.
    func testExplorePoolWithoutAPriceShowsNoValue() {
        let factory = ExploreItemFactory(
            assetManager: PriceTestAssetManager(assets: assets())
        )
        let unknown = factory.createPoolsItem(
            with: ExplorePool(
                id: "1",
                baseAssetId: priceTestXor,
                targetAssetId: priceTestVal,
                tvl: 0,
                tvlIsKnown: false
            ),
            serialNumber: "1"
        )
        XCTAssertEqual(unknown.tvl, "")

        let known = factory.createPoolsItem(
            with: ExplorePool(
                id: "1",
                baseAssetId: priceTestXor,
                targetAssetId: priceTestVal,
                tvl: 0
            ),
            serialNumber: "1"
        )
        XCTAssertEqual(known.tvl, "$" + Decimal(0).formatNumber())
    }

    func testFarmWithoutPricesShowsNoValueAndNoRate() {
        let unknown = Farm(
            id: "f", name: "XOR-VAL", baseAsset: nil, poolAsset: nil,
            rewardAsset: nil, tvl: 0, apr: 0, depositFee: 0,
            tvlIsKnown: false, aprIsKnown: false
        )
        XCTAssertEqual(unknown.tvlText(suffix: " TVL"), "")
        XCTAssertEqual(unknown.aprText(suffix: "% APR"), "")

        let known = Farm(
            id: "f", name: "XOR-VAL", baseAsset: nil, poolAsset: nil,
            rewardAsset: nil, tvl: 1_500, apr: Decimal(string: "0.12")!,
            depositFee: 0
        )
        XCTAssertEqual(known.tvlText(suffix: " TVL"), "$" + Decimal(1_500).formatNumber() + " TVL")
        XCTAssertEqual(known.aprText(suffix: "% APR"), "12% APR")
    }

    /// The Explore pool list asks again when the node gave nothing, with a
    /// growing pause, and stops once the screen that owns it is gone.
    func testExplorePoolsReloadBacksOffAndStopsWhenReleased() async throws {
        XCTAssertEqual(ExplorePoolsViewModelService.retryDelay(afterAttempts: 0), 2)
        XCTAssertEqual(ExplorePoolsViewModelService.retryDelay(afterAttempts: 1), 4)
        XCTAssertEqual(ExplorePoolsViewModelService.retryDelay(afterAttempts: 4), 32)
        XCTAssertEqual(ExplorePoolsViewModelService.retryDelay(afterAttempts: 5), 60)
        XCTAssertEqual(ExplorePoolsViewModelService.retryDelay(afterAttempts: 500), 60)

        let pools = PriceTestExplorePools()
        let pauses = Counter()
        let delays = DelayLog()
        var service: ExplorePoolsViewModelService? = ExplorePoolsViewModelService(
            itemFactory: ExploreItemFactory(
                assetManager: PriceTestAssetManager(assets: assets())
            ),
            poolsService: pools,
            apyService: PriceTestAPY(),
            fiatService: FiatService(assets: { [] }),
            pause: { seconds in
                delays.append(seconds)
                pauses.increment()
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        )
        weak var released = service

        service?.setup()
        await wait("three rounds") { pauses.value >= 3 }
        XCTAssertEqual(Array(delays.values.prefix(3)), [2, 4, 8])

        service = nil
        await wait("the service to be released") { released == nil }
        let callsAtRelease = pools.calls
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(pools.calls, callsAtRelease)
    }
}

final class DelayLog {
    private let lock = NSLock()
    private var log: [TimeInterval] = []

    var values: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return log
    }

    func append(_ value: TimeInterval) {
        lock.lock()
        log.append(value)
        lock.unlock()
    }
}

// MARK: - Market data from the shared catalog

final class PIMarketCapFromCatalogTests: XCTestCase {
    func testMarketCapOperationReadsTheSharedCatalog() throws {
        struct Payload: Decodable {
            let assets: PIConnection<PIAsset>
        }
        let catalog = try PIIndexerClient.decodeResponse(
            Payload.self,
            from: PIIndexerFixture.data("assets-page")
        ).assets.values
        let xor =
            "0x0200000000000000000000000000000000000000000000000000000000000000"
        let val =
            "0x0200040000000000000000000000000000000000000000000000000000000000"

        let operation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(
            baseUrl: PIIndexerClient.endpoint,
            assetIds: [xor, val],
            catalog: { catalog }
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        guard case let .success(values) = operation.result else {
            return XCTFail("\(String(describing: operation.result))")
        }
        XCTAssertEqual(Set(values.map(\.tokenId)), [xor, val])
        XCTAssertEqual(
            values.first { $0.tokenId == xor }?.liquidity,
            "375349458646202884981"
        )
        XCTAssertEqual(
            values.first { $0.tokenId == xor }?.hourDelta?.doubleValue,
            -10.363275404040861
        )
    }

    func testMarketCapOperationRefusesAnotherEndpoint() throws {
        var reads = 0
        let operation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(
            baseUrl: try XCTUnwrap(URL(string: "https://pi.example/graphql")),
            assetIds: ["xor"],
            catalog: {
                reads += 1
                return []
            }
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        guard case .failure = operation.result else {
            return XCTFail("An unreviewed endpoint was accepted")
        }
        XCTAssertEqual(reads, 0)
    }
}

// MARK: - Remote feature flags in App Store builds

final class PIRemoteFlagMaskingTests: XCTestCase {
    private func liveConfig() throws -> PIMobileConfig {
        struct Payload: Decodable { let mobileConfig: PIMobileConfig }
        return try PIIndexerClient.decodeResponse(
            Payload.self,
            from: PIIndexerFixture.data("mobile-config")
        ).mobileConfig
    }

    func testAppStoreBuildMasksEveryOptionalFlagThePISends() throws {
        let live = try liveConfig()

        let admitted = ProductSurfacePolicy.admitted(
            live,
            isAppStoreBuild: true
        )

        XCTAssertFalse(admitted.nexusAvailable)
        XCTAssertFalse(admitted.nexusSendsAvailable)
        XCTAssertFalse(admitted.polkamarktVisible)
        XCTAssertFalse(admitted.polkamarktMutationsAvailable)
        XCTAssertFalse(admitted.tairaDefaultVisible)
        // Nodes, the explorer and the type registry are not feature flags.
        XCTAssertEqual(admitted.nodes, live.nodes)
        XCTAssertEqual(admitted.blockExplorerUrl, live.blockExplorerUrl)
        XCTAssertEqual(admitted.substrateTypesUrl, live.substrateTypesUrl)

        // A tester build still follows PI.
        XCTAssertEqual(
            ProductSurfacePolicy.admitted(live, isAppStoreBuild: false),
            live
        )
    }

    func testAppStoreBuildStoresTheLiveFlagsAsOff() throws {
        let everythingOn = PIMobileConfig(
            blockExplorerUrl: try liveConfig().blockExplorerUrl,
            substrateTypesUrl: nil,
            nodes: try liveConfig().nodes,
            nexusAvailable: true,
            nexusSendsAvailable: true,
            polkamarktVisible: true,
            polkamarktMutationsAvailable: true,
            tairaDefaultVisible: true
        )
        for config in [try liveConfig(), everythingOn] {
            let settings = InMemorySettingsManager()
            let session = ProductionRemoteCapabilitySession.shared
            defer { session.invalidate() }

            XCTAssertTrue(
                settings.applyPIMobileConfig(
                    config,
                    refreshToken: session.beginLiveRefresh(),
                    isAppStoreBuild: true
                )
            )

            // The stored values themselves, not only what the getters say.
            XCTAssertEqual(
                settings.bool(for: SettingsKey.nexusEnabled.rawValue),
                false
            )
            XCTAssertEqual(
                settings.bool(for: SettingsKey.polkamarktEnabled.rawValue),
                false
            )
            XCTAssertEqual(
                settings.bool(for: SettingsKey.tairaRemoteDefault.rawValue),
                false
            )
            XCTAssertEqual(
                settings.bool(for: SettingsKey.nexusSendsEnabled.rawValue),
                false
            )
            XCTAssertEqual(
                settings.bool(
                    for: SettingsKey.polkamarktMutationsEnabled.rawValue
                ),
                false
            )
            XCTAssertFalse(settings.nexusEnabled)
            XCTAssertFalse(settings.polkamarktEnabled)
            XCTAssertFalse(settings.isTairaEnabled)
            // No mutation authority is published either.
            XCTAssertFalse(
                session.permitsMutation(
                    localQualification: true,
                    capability: .nexusSends
                )
            )
            XCTAssertFalse(
                session.permitsMutation(
                    localQualification: true,
                    capability: .polkamarktMutations
                )
            )
        }
    }

    /// Values an earlier (tester or pre-fix) build stored as on are read as
    /// off by a build that does not ship the surface, and are not erased.
    func testStoredFlagsAreReadThroughTheBuildsSurfacePolicy() {
        let settings = InMemorySettingsManager()
        settings.set(value: true, for: SettingsKey.nexusEnabled.rawValue)
        settings.set(value: true, for: SettingsKey.polkamarktEnabled.rawValue)
        settings.set(value: true, for: SettingsKey.tairaRemoteDefault.rawValue)

        XCTAssertEqual(
            settings.nexusEnabled,
            ProductSurfacePolicy.showsNexusPortfolio
        )
        XCTAssertEqual(
            settings.polkamarktEnabled,
            ProductSurfacePolicy.showsPolkamarkt
        )
        XCTAssertEqual(
            settings.isTairaEnabled,
            ProductSurfacePolicy.showsTairaSettings
        )

        let explicit = InMemorySettingsManager()
        explicit.isTairaEnabled = true
        XCTAssertEqual(
            explicit.isTairaEnabled,
            ProductSurfacePolicy.showsTairaSettings
        )
        XCTAssertEqual(
            explicit.string(for: SettingsKey.tairaExplicitPreference.rawValue),
            "enabled"
        )
    }

    func testSurfacePolicyMatchesTheBuildConfiguration() {
        let isAppStoreConfiguration =
            Bundle.main.object(forInfoDictionaryKey: "AppConfigName")
                as? String == "Release"
        XCTAssertEqual(
            ProductSurfacePolicy.isAppStoreBuild,
            isAppStoreConfiguration
        )
        XCTAssertEqual(
            ProductSurfacePolicy.isAppStoreBuild,
            !ProductSurfacePolicy.showsNexusPortfolio
        )
    }
}

// MARK: - The live indexer (opt-in)

/// Reads the live PI indexer with the production client: no stubs.
///
/// Opt-in, like the other live tests:
///
///     TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1 xcodebuild test-without-building ... \
///       -only-testing:SoraPassportTests/PIIndexerLiveTests
///
/// `TEST_RUNNER_SORA_LIVE_PI_ROUNDS=10` repeats the read and prints the
/// success rate.
final class PIIndexerLiveTests: XCTestCase {
    private static let xor =
        "0x0200000000000000000000000000000000000000000000000000000000000000"

    private func requireLive() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SORA_LIVE_NETWORK_TESTS"] == "1",
            "Live-network test. Set TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1 to run it."
        )
    }

    /// A client with an empty cache directory, so a last good catalog can
    /// never stand in for a failed live read. `catalogs` gives it the
    /// session of the app's shared catalog client, which does not wait for
    /// connectivity.
    private func freshClient(
        catalogs: Bool = false
    ) -> (client: PIIndexerClient, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "pi-live-\(UUID().uuidString)",
                isDirectory: true
            )
        let client = PIIndexerClient(
            session: catalogs ? PIIndexerClient.catalogSession : nil,
            cacheDirectory: directory
        )
        return (client, directory)
    }

    func testLiveIndexerServesAllAssetsPoolsAndFiatPrices() async throws {
        try requireLive()
        let rounds = max(
            1,
            Int(
                ProcessInfo.processInfo.environment["SORA_LIVE_PI_ROUNDS"] ?? ""
            ) ?? 1
        )
        var assetsOK = 0
        var poolsOK = 0
        var fiatOK = 0
        var marketCapOK = 0
        var savedOK = 0
        var largestCatalog = 0
        var failures: [String] = []

        for round in 1 ... rounds {
            let (client, directory) = freshClient(catalogs: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let started = Date()
            var catalog: [PIAsset] = []
            do {
                let read = try await client.qualifiedAllAssets()
                if
                    read.qualification?.source == .live,
                    !read.value.isEmpty,
                    read.value.contains(where: { $0.id == Self.xor })
                {
                    assetsOK += 1
                    catalog = read.value
                } else {
                    failures.append("round \(round) assets: not a live catalog with XOR")
                }
            } catch {
                failures.append("round \(round) assets: \(error)")
            }
            let assetsSeconds = Date().timeIntervalSince(started)

            let poolsStarted = Date()
            var poolCount = 0
            do {
                let read = try await client.qualifiedAllPoolXYKs()
                if read.qualification?.source == .live, !read.value.isEmpty {
                    poolsOK += 1
                    poolCount = read.value.count
                } else {
                    failures.append("round \(round) pools: not a live catalog")
                }
            } catch {
                failures.append("round \(round) pools: \(error)")
            }
            let poolsSeconds = Date().timeIntervalSince(poolsStarted)

            // What the walks saved is what the next run shows while its
            // first read is on its way: both catalogs must read back whole,
            // at their real size.
            let savedAssets = await client.savedAllAssets()
            let savedPools = await client.savedAllPoolXYKs()
            if
                !catalog.isEmpty,
                savedAssets?.value == catalog,
                poolCount > 0,
                savedPools?.value.count == poolCount
            {
                savedOK += 1
            } else {
                failures.append(
                    "round \(round) saved: assets " +
                        "\(String(describing: savedAssets?.value.count)), " +
                        "pools \(String(describing: savedPools?.value.count))"
                )
            }

            // The services the wallet screens use, over the same client.
            let fiat = await FiatService(assets: {
                try await client.allAssets()
            }).getFiat()
            let xorPrice = fiat.first { $0.id == Self.xor }?
                .priceUsd?.decimalValue
            if !fiat.isEmpty, (xorPrice ?? 0) > 0 {
                fiatOK += 1
            } else {
                failures.append("round \(round) fiat: \(fiat.count) prices, XOR \(String(describing: xorPrice))")
            }

            if !catalog.isEmpty {
                let requested = Array(catalog.prefix(40).map(\.id)) + [Self.xor]
                let operation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(
                    baseUrl: PIIndexerClient.endpoint,
                    assetIds: Array(Set(requested)),
                    catalog: { catalog }
                )
                OperationQueue().addOperations(
                    [operation],
                    waitUntilFinished: true
                )
                // The production service, for every asset of the catalog
                // (review round 4: it no longer caches on its own).
                let whole = await MarketCapService(catalog: { catalog })
                    .getMarketCap(for: catalog.map(\.id))
                if case let .success(values) = operation.result,
                   values.count == Set(requested).count,
                   whole.count == catalog.count {
                    marketCapOK += 1
                } else {
                    failures.append(
                        "round \(round) market cap: " +
                            "\(String(describing: operation.result)), " +
                            "whole catalog \(whole.count) of \(catalog.count)"
                    )
                }
            }
            largestCatalog = max(largestCatalog, catalog.count, poolCount)

            print(
                "PI live round \(round)/\(rounds): " +
                    "assets \(catalog.count) in \(String(format: "%.1f", assetsSeconds)) s, " +
                    "pools \(poolCount) in \(String(format: "%.1f", poolsSeconds)) s, " +
                    "fiat \(fiat.count) prices, XOR $\(xorPrice.map { "\($0)" } ?? "-")"
            )
        }

        print(
            "PI live summary: assets \(assetsOK)/\(rounds), " +
                "pools \(poolsOK)/\(rounds), fiat \(fiatOK)/\(rounds), " +
                "market cap \(marketCapOK)/\(rounds), " +
                "saved copies \(savedOK)/\(rounds)"
        )
        for failure in failures {
            print("PI live failure: \(failure)")
        }
        XCTAssertEqual(assetsOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(poolsOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(fiatOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(marketCapOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(savedOK, rounds, failures.joined(separator: "; "))
        // Growth is noticed long before it hurts: the walk reads at most
        // 10,000 rows (`maximumCatalogPages` pages of 100), and every price
        // in the app depends on it. On 12 October 2026 PI had 957 assets
        // and 432 pools.
        XCTAssertLessThan(
            largestCatalog,
            PIIndexerClient.maximumCatalogPages * 100 / 2,
            "A PI catalog has passed half of what one walk can read. " +
                "Plan a query for the wallet's own assets before it is full."
        )
    }

    /// Every other production read decodes and validates against the live
    /// indexer: health, configuration, referral rewards and Activity.
    func testLiveIndexerServesTheOtherProductionReads() async throws {
        try requireLive()
        let (client, directory) = freshClient()
        defer { try? FileManager.default.removeItem(at: directory) }

        let health = try await client.health(requireLive: true)
        XCTAssertGreaterThan(health.workerLatestIndexedBlock ?? 0, 27_000_000)

        let config = try await client.qualifiedMobileConfig(requireLive: true)
        XCTAssertEqual(config.qualification?.source, .live)
        XCTAssertFalse(config.value.nodes.isEmpty)
        print(
            "PI live flags: nexusAvailable \(config.value.nexusAvailable), " +
                "polkamarktVisible \(config.value.polkamarktVisible), " +
                "tairaDefaultVisible \(config.value.tairaDefaultVisible)"
        )
        // Whatever PI sends, an App Store build stores them as off.
        let admitted = ProductSurfacePolicy.admitted(
            config.value,
            isAppStoreBuild: true
        )
        XCTAssertFalse(admitted.nexusAvailable)
        XCTAssertFalse(admitted.polkamarktVisible)
        XCTAssertFalse(admitted.tairaDefaultVisible)

        // Accounts with public on-chain activity on 11 October 2026.
        let rewards = try await client.allReferrerRewards(
            address: "cnXFF4GNDVnynZsCYD95p3Nj3G52LkiPyPikSz1JAxcV5xu8c"
        )
        print("PI live referral rewards: \(rewards.count) rows")
        // A referrer with a non-zero reward on 11 October 2026 (review
        // round 4): the amounts are whole numbers of the smallest unit,
        // which is what the Friends screen converts.
        let paid = try await client.allReferrerRewards(
            address: "cnX4bgFxbJZvTB86i4186415TWMuUshjxWXkvjt6QdzchhKdT"
        )
        let total = paid.reduce(Decimal(0)) {
            $0 + FriendsPresenter.rewardAmount($1.amount?.rawValue ?? "")
        }
        XCTAssertGreaterThan(total, 0)
        print("PI live referral rewards with amounts: \(paid.count) rows, \(total) XOR")

        let history = try await client.qualifiedHistoryPageWithCoverage(
            address: "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy",
            first: 20,
            page: 2
        )
        XCTAssertEqual(history.read.qualification?.source, .live)
        XCTAssertFalse(history.read.value.values.isEmpty)
        print(
            "PI live history: page 2 has \(history.read.value.values.count) rows " +
                "of \(history.read.value.totalCount), coverage \(history.coverage.rawValue)"
        )
    }
}


// MARK: - Review round 3: nobody waits when there is something to show

extension PICatalogStoreTests {
    /// The phone was locked for two hours and PI is slow. The caller has
    /// the old catalog, with its time, without waiting; so has a second
    /// caller, who does not start a second read. The new catalog then
    /// replaces it and announces itself.
    func testAnOldCatalogIsServedAtOnceWithItsTimeWhileItsReadRuns()
        async throws
    {
        let source = Source()
        let changes = Counter()
        let store = store(
            source,
            freshFor: 600,
            staleFor: 1_800,
            onChange: { changes.increment() }
        )
        let loadedAt = wallClock(source)
        _ = try await store.values()

        source.advance(2 * 3_600)
        source.hold()
        source.result = .success(
            PIQualifiedRead(value: ["b"], qualification: nil)
        )
        let shown = await withoutWaiting(store)
        XCTAssertEqual(shown?.values, ["a"])
        XCTAssertEqual(shown?.asOf, loadedAt)
        let second = await withoutWaiting(store)
        XCTAssertEqual(second?.values, ["a"])
        XCTAssertEqual(second?.asOf, loadedAt)

        source.release()
        await store.settled()
        XCTAssertEqual(source.callCount, 2)
        XCTAssertEqual(changes.value, 2)
        let refreshed = try await store.snapshot()
        XCTAssertEqual(refreshed.values, ["b"])
        XCTAssertNil(refreshed.asOf)
    }

    /// The catalog held is the one the client read back from disk, the app
    /// comes back to the foreground, and the read that starts cannot end
    /// (no connection). The caller still has the catalog at once.
    func testAfterAReturnToTheForegroundCallersStillDoNotWait()
        async throws
    {
        let source = Source()
        let savedAt = wallClock(source).addingTimeInterval(-3_600)
        source.result = .success(cached(["saved"], savedAt: savedAt))
        let store = store(source)
        let first = try await store.snapshot()
        XCTAssertEqual(first.values, ["saved"])
        XCTAssertEqual(first.asOf, savedAt)

        source.hold()
        await store.clearBackoff()
        let shown = await withoutWaiting(store)
        XCTAssertEqual(shown?.values, ["saved"])
        XCTAssertEqual(shown?.asOf, savedAt)

        source.result = .success(
            PIQualifiedRead(value: ["live"], qualification: nil)
        )
        source.release()
        await store.settled()
        // The foreground did start a read.
        XCTAssertEqual(source.callCount, 2)
        let live = try await store.snapshot()
        XCTAssertEqual(live.values, ["live"])
        XCTAssertNil(live.asOf)
    }

    /// A live catalog whose refresh failed is shown with its time. Coming
    /// back to the foreground neither makes the caller wait nor shows the
    /// catalog as current again before a read has succeeded.
    func testAfterAReturnToTheForegroundAFailedCatalogKeepsItsTime()
        async throws
    {
        let source = Source()
        let store = store(source, freshFor: 600, staleFor: 1_800)
        let loadedAt = wallClock(source)
        _ = try await store.values()

        source.advance(700)
        source.result = .failure(URLError(.notConnectedToInternet))
        _ = try await store.snapshot()
        await store.settled()

        source.hold()
        await store.clearBackoff()
        let shown = await withoutWaiting(store)
        XCTAssertEqual(shown?.values, ["a"])
        XCTAssertEqual(shown?.asOf, loadedAt)

        source.release()
        await store.settled()
        XCTAssertEqual(source.callCount, 3)
    }

    /// A new run: nothing in memory, yesterday evening's catalog on disk,
    /// and the first read on its way or waiting for a connection. Every
    /// caller has the saved catalog at once, marked with its time; the file
    /// is read once; the live catalog then replaces it.
    func testTheSavedCatalogIsShownWhileTheFirstReadOfARunIsOnItsWay()
        async throws
    {
        let source = Source()
        let savedAt = wallClock(source).addingTimeInterval(-10 * 3_600)
        source.saved = cached(["saved"], savedAt: savedAt)
        source.hold()
        let changes = Counter()
        let store = store(source, onChange: { changes.increment() })

        let shown = await withoutWaiting(store)
        XCTAssertEqual(shown?.values, ["saved"])
        XCTAssertEqual(shown?.asOf, savedAt)
        let again = await withoutWaiting(store)
        XCTAssertEqual(again?.values, ["saved"])
        XCTAssertEqual(again?.asOf, savedAt)
        XCTAssertEqual(source.savedReadCount, 1)

        source.result = .success(
            PIQualifiedRead(value: ["live"], qualification: nil)
        )
        source.release()
        await store.settled()
        XCTAssertEqual(source.callCount, 1)
        XCTAssertEqual(changes.value, 1)
        let live = try await store.snapshot()
        XCTAssertEqual(live.values, ["live"])
        XCTAssertNil(live.asOf)
        XCTAssertEqual(source.savedReadCount, 1)
    }

    /// The same start with no connection: the read fails at once. The
    /// saved catalog stays, with its time, and the read is not repeated
    /// before its backoff has passed.
    func testTheSavedCatalogIsShownWhenTheFirstReadFails() async throws {
        let source = Source()
        let savedAt = wallClock(source).addingTimeInterval(-10 * 3_600)
        source.saved = cached(["saved"], savedAt: savedAt)
        source.result = .failure(URLError(.notConnectedToInternet))
        let store = store(source)

        let first = try await store.snapshot()
        XCTAssertEqual(first.values, ["saved"])
        XCTAssertEqual(first.asOf, savedAt)
        await store.settled()
        for _ in 0 ..< 20 {
            let later = try await store.snapshot()
            XCTAssertEqual(later.values, ["saved"])
            XCTAssertEqual(later.asOf, savedAt)
        }
        XCTAssertEqual(source.callCount, 1)
        XCTAssertEqual(source.savedReadCount, 1)
    }

    /// The saved catalog keeps its real age: one that is older than the
    /// limit is not shown, and one that is 23 hours old is not shown two
    /// hours later.
    func testASavedCatalogIsNotShownBeyondItsLimit() async throws {
        let old = Source()
        old.saved = cached(
            ["saved"],
            savedAt: wallClock(old).addingTimeInterval(-25 * 3_600)
        )
        let waited = try await store(old, lastGoodFor: 24 * 3_600).snapshot()
        XCTAssertEqual(waited.values, ["a"])
        XCTAssertNil(waited.asOf)

        let source = Source()
        let savedAt = wallClock(source).addingTimeInterval(-23 * 3_600)
        source.saved = cached(["saved"], savedAt: savedAt)
        source.result = .failure(PIIndexerError.httpStatus(503))
        let store = store(source, lastGoodFor: 24 * 3_600)
        let first = try await store.snapshot()
        XCTAssertEqual(first.values, ["saved"])
        XCTAssertEqual(first.asOf, savedAt)
        await store.settled()

        source.advance(2 * 3_600)
        do {
            _ = try await store.snapshot()
            XCTFail("A 25-hour-old catalog was shown")
        } catch {
            guard case PIIndexerError.httpStatus(503) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    /// With nothing saved the first caller waits for the read, as before.
    func testWithNothingSavedTheFirstCallerWaitsForTheRead() async throws {
        let source = Source()
        source.delayNanoseconds = 100_000_000
        let store = store(source)

        let first = try await store.snapshot()

        XCTAssertEqual(first.values, ["a"])
        XCTAssertNil(first.asOf)
        XCTAssertEqual(source.callCount, 1)
        XCTAssertEqual(source.savedReadCount, 1)
    }

    /// The saved catalog does not stand in for a response that could not be
    /// used either: once PI has answered with one, the caller gets the
    /// error.
    func testASavedCatalogDoesNotStandInForAResponseThatCannotBeUsed()
        async throws
    {
        let source = Source()
        source.saved = cached(
            ["saved"],
            savedAt: wallClock(source).addingTimeInterval(-3_600)
        )
        source.result = .failure(
            DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "volumeDayUSD")
            )
        )
        let store = store(source)

        _ = try? await store.snapshot()
        await store.settled()

        do {
            _ = try await store.snapshot()
            XCTFail("A saved catalog replaced a response that did not decode")
        } catch {
            XCTAssertTrue(error is DecodingError, "\(error)")
        }
        XCTAssertEqual(source.callCount, 1)
    }
}

/// Something a test holds back until it says so.
final class TestGate {
    private let lock = NSLock()
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func open() {
        lock.lock()
        isOpen = true
        let resumed = waiting
        waiting = []
        lock.unlock()
        resumed.forEach { $0.resume() }
    }

    private func park(_ continuation: CheckedContinuation<Void, Never>) {
        lock.lock()
        if isOpen {
            lock.unlock()
            continuation.resume()
        } else {
            waiting.append(continuation)
            lock.unlock()
        }
    }

    func passed() async {
        await withCheckedContinuation { park($0) }
    }
}

extension PIIndexerAdvancingReadTests {
    /// What a live read saved is read back by the next run without any
    /// request, with the checkpoint and the time it was saved at.
    func testTheSavedCatalogIsReadBackWithoutAnyRequest() async throws {
        _ = try indexer()
        let nothingYet = await client().savedAllAssets()
        XCTAssertNil(nothingYet)

        let good = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )
        let requests = PIStubIndexerProtocol.requests.count

        let read = await client().savedAllAssets()
        let saved = try XCTUnwrap(read)
        XCTAssertEqual(saved.value, good.value)
        XCTAssertEqual(saved.qualification?.source, .cache)
        XCTAssertEqual(
            saved.qualification?.health,
            good.qualification?.health
        )
        let savedAt = try XCTUnwrap(saved.savedAt)
        XCTAssertLessThan(abs(savedAt.timeIntervalSinceNow), 60)
        XCTAssertEqual(PIStubIndexerProtocol.requests.count, requests)

        // Another catalog has its own file.
        let pools = await client().savedAllPoolXYKs()
        XCTAssertNil(pools)
    }

    /// A new run with PI slow: prices come from the saved catalog at once,
    /// with their time, through the store and the fiat service as the app
    /// wires them.
    func testANewRunShowsTheSavedPricesWhileTheFirstReadIsOnItsWay()
        async throws
    {
        _ = try indexer()
        let good = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        let restarted = client()
        let slow = TestGate()
        let store = PICatalogStore<PIAsset>(
            freshFor: 600,
            staleFor: 1_800,
            saved: { await restarted.savedAllAssets() },
            load: {
                await slow.passed()
                return try await restarted.qualifiedAllAssets(
                    pageSize: 3,
                    maximumPages: 5
                )
            }
        )
        let service = FiatService(catalog: { try await store.snapshot() })

        let answered = XCTestExpectation(description: "prices")
        let call = Task { () -> FiatSnapshot in
            let snapshot = await service.getFiatSnapshot()
            answered.fulfill()
            return snapshot
        }
        let outcome = await XCTWaiter().fulfillment(
            of: [answered],
            timeout: 5
        )
        XCTAssertEqual(outcome, .completed, "Prices waited for the read")
        slow.open()
        let shown = await call.value
        XCTAssertEqual(shown.data.count, good.value.count)
        XCTAssertNotNil(shown.asOf)

        await store.settled()
        let live = await service.getFiatSnapshot()
        XCTAssertEqual(live.data.count, good.value.count)
        XCTAssertNil(live.asOf)
    }

    /// With no connection a catalog read fails at once instead of waiting
    /// for one; the other production reads keep waiting.
    func testTheCatalogSessionDoesNotWaitForAConnection() {
        let configuration = PIIndexerClient.catalogSession.configuration
        XCTAssertFalse(configuration.waitsForConnectivity)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 20)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 30)
        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(
            configuration.requestCachePolicy,
            .reloadIgnoringLocalCacheData
        )
    }
}

// MARK: - Review round 3: the Explore pool list is scanned once

/// A node that answers `state_getStorage` for pool reserves and counts the
/// requests.
private final class ReserveNode: JSONRPCEngine {
    var url: URL? = URL(string: "wss://node.invalid")
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private let lock = NSLock()
    private var requestId: UInt16 = 0
    private var count = 0
    private var ready = true

    /// `false`: the node does not answer (not connected yet).
    var isReady: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return ready
        }
        set {
            lock.lock()
            ready = newValue
            lock.unlock()
        }
    }

    var storageReads: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    /// 10 tokens of 18 decimals as `PoolXYK.Reserves`: two little-endian
    /// `u128`, the reserves and the fees.
    static let tenTokens: String = {
        var value = UInt64(10_000_000_000_000_000_000).littleEndian
        let reserves = withUnsafeBytes(of: &value) { Data($0) } +
            Data(repeating: 0, count: 8)
        let fees = Data(repeating: 0, count: 16)
        return "0x" + (reserves + fees)
            .map { String(format: "%02x", $0) }
            .joined()
    }()

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Swift.Error>) -> Void)?
    ) throws -> UInt16 {
        lock.lock()
        if method == "state_getStorage" {
            count += 1
        }
        requestId += 1
        let id = requestId
        let answers = ready
        lock.unlock()

        DispatchQueue.global().async {
            guard
                answers,
                let data = try? JSONSerialization.data(
                    withJSONObject: Self.tenTokens,
                    options: [.fragmentsAllowed]
                ),
                let value = try? JSONDecoder().decode(T.self, from: data)
            else {
                closure?(.failure(NSError(domain: "ReserveNode", code: 1)))
                return
            }
            closure?(.success(value))
        }
        return id
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Swift.Error, Bool) -> Void
    ) throws -> UInt16 {
        throw NSError(domain: "ReserveNode", code: 2)
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 0 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url _: URL) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

final class ExplorePoolScanTests: XCTestCase {
    private let pswap =
        "0x0200050000000000000000000000000000000000000000000000000000000000"
    private let xstusd =
        "0x0200080000000000000000000000000000000000000000000000000000000000"

    private func asset(_ id: String, _ symbol: String) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: symbol, visible: true)
    }

    /// XOR and XSTUSD are the base assets; VAL and PSWAP make two pools
    /// with each: four pairs, four storage reads per scan.
    private func assets() -> [AssetInfo] {
        [
            asset(priceTestXor, "XOR"),
            asset(priceTestVal, "VAL"),
            asset(pswap, "PSWAP"),
            asset(xstusd, "XSTUSD"),
        ]
    }

    private let pairs = 4

    private func service(
        _ node: ReserveNode
    ) -> (ExplorePoolsService, PolkaswapNetworkOperationFactory) {
        // The service holds the factory weakly, as in the app.
        let factory = PolkaswapNetworkOperationFactory(engine: node)
        let service = ExplorePoolsService(
            assetInfos: assets(),
            fiatService: nil,
            polkaswapOperationFactory: factory,
            networkFacade: nil
        )
        return (service, factory)
    }

    private func wait(
        _ what: String,
        until condition: @escaping () -> Bool
    ) async {
        for _ in 0 ..< 500 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    /// The reserves are read from the node once. Valuing the list again,
    /// with or without prices, reads nothing.
    func testReservesAreScannedOnceWhateverThePrices() async throws {
        let node = ReserveNode()
        let (service, factory) = service(node)

        let withoutPrices = try await service.getPools(with: [])
        XCTAssertEqual(withoutPrices.count, pairs)
        XCTAssertTrue(withoutPrices.allSatisfy { !$0.tvlIsKnown })
        XCTAssertEqual(node.storageReads, pairs)

        // Still no prices: the list is kept all the same.
        let again = try await service.getPools(with: [])
        XCTAssertEqual(again.map(\.id), withoutPrices.map(\.id))
        XCTAssertEqual(node.storageReads, pairs)

        // Prices arrive: the same reserves are valued, nothing is read.
        let prices = [
            PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("2")),
            PIExactFiatData(id: xstusd, priceUsd: try PIQuantity("1")),
        ]
        let valued = try await service.getPools(with: prices)
        XCTAssertEqual(node.storageReads, pairs)
        XCTAssertEqual(valued.count, pairs)
        XCTAssertTrue(valued.allSatisfy(\.tvlIsKnown))
        // 10 tokens of the base asset on each side: 2 x 10 x price.
        XCTAssertEqual(
            valued.map(\.tvl),
            [40, 40, 20, 20].map { Decimal($0) }
        )
        XCTAssertEqual(
            valued.map(\.baseAssetId),
            [priceTestXor, priceTestXor, xstusd, xstusd]
        )
        // Pools of equal value stay in the order of the scan.
        XCTAssertEqual(
            valued.map(\.targetAssetId),
            [priceTestVal, pswap, priceTestVal, pswap]
        )

        // Prices are lost again: values are unknown, the list stays.
        let lost = try await service.getPools(with: [])
        XCTAssertEqual(lost.count, pairs)
        XCTAssertTrue(lost.allSatisfy { !$0.tvlIsKnown })
        XCTAssertEqual(node.storageReads, pairs)
        withExtendedLifetime(factory) {}
    }

    /// Callers that arrive while the scan runs join it.
    func testConcurrentCallersShareOneScan() async throws {
        let node = ReserveNode()
        let (service, factory) = service(node)

        let results = await withTaskGroup(
            of: Int.self
        ) { group -> [Int] in
            for _ in 0 ..< 8 {
                group.addTask {
                    ((try? await service.getPools(with: [])) ?? []).count
                }
            }
            var all: [Int] = []
            for await count in group {
                all.append(count)
            }
            return all
        }

        XCTAssertEqual(results, Array(repeating: pairs, count: 8))
        XCTAssertEqual(node.storageReads, pairs)
        withExtendedLifetime(factory) {}
    }

    /// A scan the node did not answer is not kept: the next call scans
    /// again, and that list is kept.
    func testAScanThatFoundNothingIsNotKept() async throws {
        let node = ReserveNode()
        node.isReady = false
        let (service, factory) = service(node)

        let nothing = try await service.getPools(with: [])
        XCTAssertTrue(nothing.isEmpty)
        XCTAssertEqual(node.storageReads, pairs)

        node.isReady = true
        let found = try await service.getPools(with: [])
        XCTAssertEqual(found.count, pairs)
        XCTAssertEqual(node.storageReads, 2 * pairs)

        _ = try await service.getPools(with: [])
        XCTAssertEqual(node.storageReads, 2 * pairs)
        withExtendedLifetime(factory) {}
    }

    /// The reviewer's case through the screen's own service: PI gives no
    /// prices, and "prices changed" is announced again and again (each
    /// failed read and each return to the foreground does). The node is
    /// read once, and the list on screen never goes back to placeholders.
    func testPriceNotificationsWithoutPricesDoNotScanTheNodeAgain()
        async throws
    {
        let node = ReserveNode()
        let (pools, factory) = service(node)
        let manager = PriceTestAssetManager(assets: assets())
        let service = ExplorePoolsViewModelService(
            itemFactory: ExploreItemFactory(assetManager: manager),
            poolsService: pools,
            apyService: PriceTestAPY(),
            fiatService: FiatService(assets: {
                throw PIIndexerError.httpStatus(503)
            }),
            pause: { _ in
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        )
        let shown = ShownPoolLists()
        let subscription = service.$viewModels.sink { shown.append($0) }

        service.setup()
        await wait("the pool list") {
            shown.last.count == self.pairs &&
                shown.last.allSatisfy { $0.apy != nil }
        }
        XCTAssertEqual(node.storageReads, pairs)
        XCTAssertTrue(shown.last.allSatisfy { $0.tvl == "" })
        let listsBefore = shown.count

        for _ in 0 ..< 2 {
            NotificationCenter.default.post(
                name: PICatalogs.pricesDidChange,
                object: nil
            )
            // The observer runs on the main queue; let the round it
            // starts end.
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        XCTAssertEqual(node.storageReads, pairs)
        // Whatever was put on screen after the first full list was a full
        // list again: no row went back to its loading placeholder.
        for list in shown.all.dropFirst(listsBefore) {
            XCTAssertEqual(list.count, pairs)
            XCTAssertTrue(list.allSatisfy { $0.apy != nil })
        }
        subscription.cancel()
        withExtendedLifetime(factory) {}
    }

    /// Prices that arrive later value the list that is on screen, without
    /// another scan.
    func testPricesThatArriveLaterValueTheListOnScreen() async throws {
        let node = ReserveNode()
        let (pools, factory) = service(node)
        let manager = PriceTestAssetManager(assets: assets())
        let prices = SwitchablePrices()
        let service = ExplorePoolsViewModelService(
            itemFactory: ExploreItemFactory(assetManager: manager),
            poolsService: pools,
            apyService: PriceTestAPY(),
            fiatService: FiatService(assets: { try prices.assets() }),
            pause: { _ in
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        )
        let shown = ShownPoolLists()
        let subscription = service.$viewModels.sink { shown.append($0) }

        service.setup()
        await wait("the pool list") {
            shown.last.count == self.pairs &&
                shown.last.allSatisfy { $0.apy != nil }
        }
        XCTAssertTrue(shown.last.allSatisfy { $0.tvl == "" })

        prices.set([
            PIAsset(
                id: priceTestXor,
                priceUSD: try PIQuantity("2"),
                liquidity: nil,
                priceChangeDay: nil
            ),
        ])
        NotificationCenter.default.post(
            name: PICatalogs.pricesDidChange,
            object: nil
        )
        await wait("the values") {
            shown.last.contains { $0.tvl == "$" + Decimal(40).formatNumber() }
        }

        XCTAssertEqual(node.storageReads, pairs)
        // The XOR pools have a value and come first; the XSTUSD pools,
        // whose base asset has no price, show none.
        XCTAssertEqual(
            shown.last.map(\.tvl),
            [
                "$" + Decimal(40).formatNumber(),
                "$" + Decimal(40).formatNumber(),
                "",
                "",
            ]
        )
        subscription.cancel()
        withExtendedLifetime(factory) {}
    }
}

/// Every pool list a screen was given, in order.
private final class ShownPoolLists {
    private let lock = NSLock()
    private var lists: [[ExplorePoolViewModel]] = []

    func append(_ list: [ExplorePoolViewModel]) {
        lock.lock()
        lists.append(list)
        lock.unlock()
    }

    var all: [[ExplorePoolViewModel]] {
        lock.lock()
        defer { lock.unlock() }
        return lists
    }

    var count: Int { all.count }
    var last: [ExplorePoolViewModel] { all.last ?? [] }
}

/// A price source the test changes.
private final class SwitchablePrices {
    private let lock = NSLock()
    private var current: [PIAsset]?

    func set(_ assets: [PIAsset]) {
        lock.lock()
        current = assets
        lock.unlock()
    }

    func assets() throws -> [PIAsset] {
        lock.lock()
        defer { lock.unlock() }
        guard let current else {
            throw PIIndexerError.httpStatus(503)
        }
        return current
    }
}

// MARK: - Review round 3: actions do not wait for prices or APY

/// A price service that does not answer until the test lets it.
private actor HeldFiat: FiatServiceProtocol {
    private var answer: [PIExactFiatData]?
    private var waiting: [CheckedContinuation<[PIExactFiatData], Never>] = []
    private(set) var calls = 0

    func getFiat() async -> [PIExactFiatData] {
        calls += 1
        if let answer {
            return answer
        }
        return await withCheckedContinuation { waiting.append($0) }
    }

    func release(_ data: [PIExactFiatData]) {
        answer = data
        let resumed = waiting
        waiting = []
        resumed.forEach { $0.resume(returning: data) }
    }
}

/// An APY service that does not answer until the test lets it.
private actor HeldAPY: APYServiceProtocol {
    private var answer: Decimal??
    private var waiting: [CheckedContinuation<Decimal?, Never>] = []

    func getApy(for _: String, targetAssetId _: String) async -> Decimal? {
        if let answer {
            return answer
        }
        return await withCheckedContinuation { waiting.append($0) }
    }

    func setup(factory _: PolkaswapNetworkOperationFactoryProtocol) {}

    func release(_ apy: Decimal?) {
        answer = .some(apy)
        let resumed = waiting
        waiting = []
        resumed.forEach { $0.resume(returning: apy) }
    }
}

private final class ActionTestQREncoder: WalletQREncoderProtocol {
    func encode(receiverInfo _: ReceiveInfo) throws -> Data {
        Data("substrate:test".utf8)
    }
}

private struct ActionTestShareFactory: AccountShareFactoryProtocol {
    func createSources(for _: ReceiveInfo, qrImage _: UIImage) -> [Any] { [] }
}

private final class ActionTestFeeProvider: FeeProviderProtocol {
    let fee: Decimal

    init(fee: Decimal) {
        self.fee = fee
    }

    func getFee(for _: TransactionType, completion: @escaping (Decimal) -> Void) {
        completion(fee)
    }

    func getFee(for _: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
        completion(fee)
    }

    func getFee(for _: any RuntimeCallable) async -> Decimal { fee }
    func getFee(for _: TransactionType) async -> Decimal { fee }
}

private final class ActionTestLPFee: LPFeeServiceProtocol {
    func getLpfee(with _: UInt32) -> String { "0.3%" }
}

private struct ActionTestDexLoader: DexInfoLoading {
    func loadDexInfos(completion: @escaping (Result<[DexInfo], Swift.Error>) -> Void) {
        completion(.success([]))
    }
}

private final class ActionTestPools: PoolsServiceInputProtocol {
    let state: PoolNetworkState
    let pool: PoolInfo?

    init(state: PoolNetworkState, pool: PoolInfo?) {
        self.state = state
        self.pool = pool
    }

    func loadAccountPools() {}
    func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
    func updatePools(_: [PoolInfo]) {}
    func getPool(by _: String) -> PoolInfo? { pool }
    func getPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPairState(baseAssetId _: String, targetAssetId _: String) async throws -> PoolNetworkState { state }
    func loadPools(currentAsset _: AssetInfo) -> [PoolInfo] { [] }
    func loadTargetPools(for _: String) -> [PoolInfo] { [] }
    func appendDelegate(delegate _: PoolsServiceOutput) {}
}

private final class ActionTestFarming: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with _: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

/// The items a screen was given, in order.
private final class ShownItems {
    private let lock = NSLock()
    private var items: [ReceiveItem] = []

    func append(_ item: ReceiveItem) {
        lock.lock()
        items.append(item)
        lock.unlock()
    }

    var all: [ReceiveItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

final class PIActionsDoNotWaitForPricesTests: XCTestCase {
    private func assets() -> [AssetInfo] {
        [
            AssetInfo(id: priceTestXor, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: priceTestVal, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "SORA Validator Token", visible: true),
        ]
    }

    private func balances() -> [BalanceData] {
        [
            BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: Decimal(100))),
            BalanceData(identifier: priceTestVal, balance: AmountDecimal(value: Decimal(100))),
        ]
    }

    private func wait(
        _ what: String,
        seconds: TimeInterval = 5,
        until condition: @escaping () -> Bool
    ) async {
        let rounds = Int(seconds * 100)
        for _ in 0 ..< rounds where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    private func xorPrice() throws -> [PIExactFiatData] {
        [PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("2"))]
    }

    /// Receive: the code and the address appear while the price read is
    /// still running (30 s with no connection before this change). The
    /// fiat text of the requested amount is filled in when prices arrive.
    func testReceiveShowsItsCodeWhileThePriceReadIsStillRunning()
        async throws
    {
        let fiat = HeldFiat()
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: balances())
        let viewModel = ReceiveViewModel(
            qrService: WalletQRService(
                operationFactory: WalletQROperationFactory(),
                encoder: ActionTestQREncoder()
            ),
            sharingFactory: ActionTestShareFactory(),
            accountId: "00",
            address: "",
            selectedAsset: assets()[0],
            amount: AmountDecimal(value: Decimal(2)),
            fiatService: fiat,
            assetProvider: provider,
            assetManager: manager
        )
        let shown = ShownItems()
        viewModel.setupItems = { items in
            items.compactMap { $0 as? ReceiveItem }.forEach(shown.append)
        }

        viewModel.viewDidLoad()
        await wait("the code, without prices") { !shown.all.isEmpty }

        let first = try XCTUnwrap(shown.all.first)
        XCTAssertNotNil(first.qrImage)
        XCTAssertEqual(first.sendAssetViewModel?.amount, "2")
        XCTAssertEqual(first.sendAssetViewModel?.fiat, "")

        await fiat.release(try xorPrice())
        await wait("the fiat text") {
            shown.all.last?.sendAssetViewModel?.fiat == "$4"
        }
        XCTAssertNotNil(shown.all.last?.qrImage)
        let calls = await fiat.calls
        XCTAssertEqual(calls, 1)
        withExtendedLifetime((fiat, manager, provider)) {}
    }

    /// Receive without a requested amount shows no fiat text, so it does
    /// not ask for prices at all.
    func testReceiveWithoutAnAmountDoesNotAskForPrices() async throws {
        let fiat = HeldFiat()
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: balances())
        let viewModel = ReceiveViewModel(
            qrService: WalletQRService(
                operationFactory: WalletQROperationFactory(),
                encoder: ActionTestQREncoder()
            ),
            sharingFactory: ActionTestShareFactory(),
            accountId: "00",
            address: "",
            selectedAsset: assets()[0],
            fiatService: fiat,
            assetProvider: provider,
            assetManager: manager
        )
        let shown = ShownItems()
        viewModel.setupItems = { items in
            items.compactMap { $0 as? ReceiveItem }.forEach(shown.append)
        }

        viewModel.viewDidLoad()
        await wait("the code") { !shown.all.isEmpty }

        XCTAssertNotNil(shown.all.first?.qrImage)
        XCTAssertNil(shown.all.first?.sendAssetViewModel)
        try await Task.sleep(nanoseconds: 100_000_000)
        let calls = await fiat.calls
        XCTAssertEqual(calls, 0)
        withExtendedLifetime((fiat, manager, provider)) {}
    }

    /// Swap: the details (and with them Review) come from the quote and
    /// the fee while the price read is still running. Prices that arrive
    /// later are filled into the details.
    func testSwapReviewDoesNotWaitForPrices() async throws {
        let fiat = HeldFiat()
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: balances())
        let events = EventCenter()
        let viewModel = SwapViewModel(
            selectedTokenId: priceTestXor,
            selectedSecondTokenId: priceTestVal,
            wireframe: nil,
            fiatService: fiat,
            assetManager: manager,
            detailsFactory: DetailViewModelFactory(assetManager: manager),
            eventCenter: events,
            interactor: PolkaswapMainInteractor(
                operationManager: OperationManager(),
                eventCenter: events,
                dexService: DexInfoService(loader: ActionTestDexLoader())
            ),
            networkFacade: nil,
            assetsProvider: provider,
            lpServiceFee: ActionTestLPFee(),
            polkaswapNetworkFacade: nil,
            marketCapService: PriceTestMarketCap(),
            feeProvider: ActionTestFeeProvider(fee: Decimal(string: "0.5")!)
        )
        viewModel.firstAssetId = priceTestXor
        viewModel.secondAssetId = priceTestVal
        viewModel.inputedFirstAmount = 1

        let reviewed = XCTestExpectation(description: "details from the quote")
        viewModel.updateDetails(
            params: PolkaswapMainInteractorQuoteParams(
                fromAssetId: priceTestXor,
                toAssetId: priceTestVal,
                amount: "1000000000000000000",
                swapVariant: .desiredInput,
                liquiditySources: [],
                filterMode: .disabled
            ),
            quote: SwapValues(
                amount: "2000000000000000000",
                route: [priceTestXor, priceTestVal]
            ),
            dexId: 0
        ) {
            reviewed.fulfill()
        }
        let outcome = await XCTWaiter().fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(outcome, .completed, "Review waited for the price read")

        XCTAssertEqual(viewModel.amounts?.toAmount, 2)
        let fee = try XCTUnwrap(viewModel.details.last)
        XCTAssertEqual(fee.assetAmountText.attributedString.string, "0.5 XOR")
        XCTAssertEqual(fee.fiatAmountText?.attributedString.string, "")

        await fiat.release(try xorPrice())
        await wait("the fee in fiat") {
            viewModel.details.last?.fiatAmountText?.attributedString.string == "$1"
        }
        XCTAssertEqual(viewModel.details.count, 5)
        withExtendedLifetime((fiat, manager, provider)) {}
    }

    /// Supply liquidity: the fee, which enables the button, is set while
    /// the pool catalog (APY) is still being read. The APY row appears when
    /// it arrives.
    func testSupplyLiquidityFeeDoesNotWaitForTheAPY() async throws {
        let apy = HeldAPY()
        let fiat = FiatService(assets: { [] })
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: balances())
        let pools = ActionTestPools(
            state: PoolNetworkState(isPresented: false, isEnabled: true),
            pool: nil
        )
        let network = WalletNetworkOperationFactoryProtocolMock()
        network.liquidityFeeClosure = { _ in Decimal(string: "0.5")! }
        let viewModel = SupplyLiquidityViewModel(
            wireframe: nil,
            poolInfo: nil,
            fiatService: fiat,
            apyService: apy,
            poolsService: pools,
            assetManager: manager,
            detailsFactory: DetailViewModelFactory(assetManager: manager),
            operationFactory: network,
            assetsProvider: provider,
            marketCapService: PriceTestMarketCap()
        )
        await MainActor.run {
            viewModel.firstAssetId = priceTestXor
            viewModel.secondAssetId = priceTestVal
            viewModel.inputedFirstAmount = 1
            viewModel.inputedSecondAmount = 2
        }

        // The pair is checked first; ask until the details are there,
        // giving each request a second on a busy machine.
        var shown = false
        for _ in 0 ..< 10 where !shown {
            await MainActor.run { viewModel.updateDetails() }
            for _ in 0 ..< 20 where !shown {
                try await Task.sleep(nanoseconds: 50_000_000)
                shown = await MainActor.run { !viewModel.details.isEmpty }
            }
        }
        XCTAssertTrue(shown, "The fee waited for the APY")
        let before = await MainActor.run { viewModel.details }
        XCTAssertEqual(
            before.last?.assetAmountText.attributedString.string,
            "0.5 XOR"
        )
        XCTAssertFalse(before.contains { $0.title == SoraPassport.Constants.apyTitle })

        await apy.release(Decimal(string: "0.12")!)
        await wait("the APY row") {
            viewModel.details.contains {
                $0.title == SoraPassport.Constants.apyTitle &&
                    $0.assetAmountText.attributedString.string == "12% APY"
            }
        }
        withExtendedLifetime((fiat, apy, manager, provider, pools)) {}
    }

    /// Remove liquidity: the same for the fee, with prices and the APY
    /// both still being read.
    func testRemoveLiquidityFeeDoesNotWaitForPricesOrTheAPY() async throws {
        let apy = HeldAPY()
        let fiat = HeldFiat()
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: balances())
        let pool = PoolInfo(
            baseAssetId: priceTestXor,
            targetAssetId: priceTestVal,
            poolId: "pool",
            accountId: "",
            yourPoolShare: 10,
            baseAssetPooledByAccount: 10,
            targetAssetPooledByAccount: 20,
            baseAssetPooledTotal: 100,
            targetAssetPooledTotal: 200,
            totalIssuances: 100,
            baseAssetReserves: 100,
            targetAssetReserves: 200,
            accountPoolBalance: 10
        )
        let pools = ActionTestPools(
            state: PoolNetworkState(isPresented: true, isEnabled: true),
            pool: pool
        )
        let network = WalletNetworkOperationFactoryProtocolMock()
        network.liquidityFeeClosure = { _ in Decimal(string: "0.5")! }
        let viewModel = RemoveLiquidityViewModel(
            wireframe: nil,
            poolInfo: pool,
            farms: [],
            apyService: apy,
            fiatService: fiat,
            poolsService: pools,
            assetManager: manager,
            detailsFactory: DetailViewModelFactory(assetManager: manager),
            providerFactory: BalanceProviderFactory(
                accountId: "",
                cacheFacade: CoreDataCacheFacade.shared,
                networkOperationFactory: network,
                identifierFactory: SingleProviderIdentifierFactory()
            ),
            operationFactory: network,
            assetsProvider: provider,
            farmingService: ActionTestFarming(),
            marketCapService: PriceTestMarketCap()
        )
        await MainActor.run { viewModel.viewDidLoad() }

        // The pair is checked first; ask until the details are there,
        // giving each request a second on a busy machine.
        var shown = false
        for _ in 0 ..< 10 where !shown {
            await MainActor.run {
                viewModel.inputedFirstAmount = 1
                viewModel.inputedSecondAmount = 2
                viewModel.updateDetails()
            }
            for _ in 0 ..< 20 where !shown {
                try await Task.sleep(nanoseconds: 50_000_000)
                shown = await MainActor.run { !viewModel.details.isEmpty }
            }
        }
        XCTAssertTrue(shown, "The fee waited for prices or the APY")
        let before = await MainActor.run { viewModel.details }
        let feeRow = try XCTUnwrap(
            before.first {
                $0.assetAmountText.attributedString.string == "0.5 XOR"
            }
        )
        XCTAssertEqual(feeRow.fiatAmountText?.attributedString.string, "")
        // The APY is not known yet: its row has no rate, not "0% APY".
        let apyRow = try XCTUnwrap(
            before.first { $0.title == SoraPassport.Constants.apyTitle }
        )
        XCTAssertEqual(apyRow.assetAmountText.attributedString.string, "")

        await fiat.release(try xorPrice())
        await wait("the fee in fiat") {
            viewModel.details.contains {
                $0.fiatAmountText?.attributedString.string == "$1"
            }
        }
        await apy.release(Decimal(string: "0.12")!)
        await wait("the APY") {
            viewModel.details.contains {
                $0.title == SoraPassport.Constants.apyTitle &&
                    $0.assetAmountText.attributedString.string == "12% APY"
            }
        }
        withExtendedLifetime((fiat, apy, manager, provider, pools)) {}
    }
}

// MARK: - Review round 4: numbers the indexer may send

final class PIRound4WireTests: XCTestCase {
    private struct AssetsPayload: Decodable {
        let assets: PIConnection<PIAsset>
    }

    private struct HistoryPayload: Decodable {
        let historyElements: PIConnection<PIHistoryElement>
    }

    private struct RewardsPayload: Decodable {
        let referrerRewards: PIConnection<PIReferrerReward>
    }

    private struct GenericPayload: Decodable {
        let data: PIJSONValue
    }

    private func assetPage(priceUSD: String) -> Data {
        Data(
            """
            {"data":{"assets":{"nodes":[{"id":\
            "0x0200000000000000000000000000000000000000000000000000000000000000",\
            "priceUSD":\(priceUSD),"liquidity":"1","priceChangeDay":0}],\
            "pageInfo":{"hasNextPage":false,"hasPreviousPage":false,\
            "startCursor":"a","endCursor":"a"},"totalCount":1}}}
            """.utf8
        )
    }

    /// A price written with an exponent no machine integer holds. The first
    /// one is `Int.min`: taking its absolute value stopped the process, on
    /// every launch, for as long as PI (or anything that can alter its
    /// answer) served it. All of them are refused as an invalid quantity.
    func testAQuantityWithAnExtremeExponentIsRefusedAndTheAppKeepsRunning() {
        for exponent in [
            "-9223372036854775808",
            "9223372036854775807",
            "-9223372036854775809",
            "123456789012345678901234567890",
            "-00000000000000000000000000004097",
            "4097",
            "+99999",
        ] {
            XCTAssertThrowsError(
                try PIQuantity.plainDecimal(fromJSONNumber: "1e\(exponent)"),
                exponent
            ) { error in
                guard case PIIndexerError.invalidQuantity = error else {
                    return XCTFail("\(exponent): \(error)")
                }
            }
            XCTAssertThrowsError(
                try PIIndexerClient.decodeResponse(
                    AssetsPayload.self,
                    from: assetPage(priceUSD: "1e\(exponent)")
                ),
                exponent
            ) { error in
                guard case PIIndexerError.invalidQuantity = error else {
                    return XCTFail("\(exponent): \(error)")
                }
            }
        }
    }

    /// The bound is on the size of the exponent, not on how it is written.
    func testExponentsWithinTheBoundKeepEveryDigit() throws {
        let cases = [
            ("1.5e0003", "1500"),
            ("25e-4", "0.0025"),
            ("1E+2", "100"),
            ("7e-0", "7"),
            ("0e5", "0"),
            ("12.50e-00001", "1.25"),
            ("-3.25e1", "-32.5"),
            ("1e4000", "1" + String(repeating: "0", count: 4_000)),
        ]
        for (number, plain) in cases {
            XCTAssertEqual(
                try PIQuantity.plainDecimal(fromJSONNumber: number),
                plain,
                number
            )
        }
        let page = try PIIndexerClient.decodeResponse(
            AssetsPayload.self,
            from: assetPage(priceUSD: "5.40462719e-0000002")
        ).assets
        XCTAssertEqual(page.values.first?.priceUSD?.rawValue, "0.0540462719")
    }

    /// The mismatch behind I4, for Activity. PI writes the USD values of
    /// history rows as strings today and `volumeDayUSD` as a number; if it
    /// changes one of these fields, or one old row holds a fractional
    /// number, the page with that row must still load. The captured page
    /// is used with four of its values rewritten as JSON numbers.
    func testAHistoryRowWithNumericValuesDecodesExactlyAndSurvivesTheCache()
        async throws
    {
        let account = "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy"
        var text = try XCTUnwrap(
            String(
                data: PIIndexerFixture.data("history-signer-page"),
                encoding: .utf8
            )
        )
        let rewrites = [
            (#""amountUSD":"179.81268359""#, #""amountUSD":179.81268359"#),
            (
                #""exchangeVolumeUSD":"29.6051847""#,
                #""exchangeVolumeUSD":2.96051847e1"#
            ),
            // Twenty significant digits: more than a Double holds.
            (
                #""baseAssetAmount":"29.605184708966599424""#,
                #""baseAssetAmount":29.605184708966599424"#
            ),
            // Numbers as array elements, one beyond 64 bits.
            (
                #""targetAssetAmountUSD":"22.07327858""#,
                #""targetAssetAmountUSD":[22.07327858,123456789012345678901234567890]"#
            ),
        ]
        for (string, number) in rewrites {
            XCTAssertTrue(text.contains(string), string)
            text = text.replacingOccurrences(of: string, with: number)
        }

        let page = try PIIndexerClient.decodeResponse(
            HistoryPayload.self,
            from: Data(text.utf8)
        ).historyElements
        let values = try PIHistoryPageValidator.validate(
            page,
            hasPriorPage: false,
            pageSize: 4
        )
        XCTAssertEqual(values.count, 4)
        guard
            case let .object(bond)? = values[0].data,
            case let .object(swap)? = values[3].data
        else {
            return XCTFail("The rows have no data object")
        }
        XCTAssertEqual(bond["amountUSD"], .number("179.81268359"))
        XCTAssertEqual(bond["amount"], .string("33"))
        XCTAssertEqual(swap["exchangeVolumeUSD"], .number("29.6051847"))
        XCTAssertEqual(
            swap["baseAssetAmount"],
            .number("29.605184708966599424")
        )
        XCTAssertEqual(
            swap["targetAssetAmountUSD"],
            .array([
                .number("22.07327858"),
                .number("123456789012345678901234567890"),
            ])
        )

        // The validated history cache, which Activity falls back to, keeps
        // the page and reads the same digits back.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "pi-history-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PIValidatedHistoryCache(baseURL: directory)
        await cache.save(
            address: account,
            count: 4,
            page: 1,
            finalizedCheckpoint: 27_992_164,
            indexedCheckpointHash: nil,
            endCursor: page.pageInfo.endCursor,
            endReached: !page.pageInfo.hasNextPage,
            elements: values
        )
        let loaded = await cache.load(address: account, count: 4, page: 1)
        let saved = try XCTUnwrap(loaded, "The page was not kept")
        guard case let .object(savedSwap)? = saved.elements[3].data else {
            return XCTFail("The saved row has no data object")
        }
        XCTAssertEqual(
            savedSwap["baseAssetAmount"],
            .string("29.605184708966599424")
        )
        XCTAssertEqual(
            savedSwap["targetAssetAmountUSD"],
            .array([
                .string("22.07327858"),
                .string("123456789012345678901234567890"),
            ])
        )

        // Without the text of the response a fractional number is still
        // refused rather than rounded.
        XCTAssertThrowsError(
            try JSONDecoder().decode(PIJSONValue.self, from: Data("1.5".utf8))
        )
    }

    /// A member whose name is a number (`"0"`) reports itself to the
    /// decoder like an array index; its value is still found.
    func testNumbersUnderNumericMemberNamesAreFound() throws {
        let payload = try PIIndexerClient.decodeResponse(
            GenericPayload.self,
            from: Data(#"{"data":{"data":{"0":1.5,"7":[2.25],"n":{"3":-0.125}}}}"#.utf8)
        )
        XCTAssertEqual(
            payload.data,
            .object([
                "0": .number("1.5"),
                "7": .array([.number("2.25")]),
                "n": .object(["3": .number("-0.125")]),
            ])
        )
    }

    // MARK: GraphQL errors and failures where PI gave no answer

    private func errors(_ list: String) -> Data {
        Data(#"{"errors":[\#(list)],"data":null}"#.utf8)
    }

    /// PI reports its own failures the way it reports a refused query:
    /// HTTP 200 with `errors`. The code tells them apart. A failure on PI's
    /// side takes the retry and the last good value; a refusal selects
    /// the fallback query shape and never an older answer.
    func testGraphQLErrorsAreToldApartByTheirCode() {
        func outcome(_ list: String) -> PIIndexerError? {
            do {
                _ = try PIIndexerClient.decodeResponse(
                    AssetsPayload.self,
                    from: errors(list)
                )
                return nil
            } catch {
                return error as? PIIndexerError
            }
        }
        func isServiceFailure(_ error: PIIndexerError?) -> Bool {
            if case .serviceFailure? = error { return true }
            return false
        }
        func isRefusal(_ error: PIIndexerError?) -> Bool {
            if case .graphQLErrors? = error { return true }
            return false
        }
        let internalError =
            #"{"message":"db","extensions":{"code":"INTERNAL_SERVER_ERROR"}}"#
        let refusal =
            #"{"message":"filter","extensions":{"code":"BAD_USER_INPUT"}}"#

        XCTAssertTrue(isServiceFailure(outcome(internalError)))
        XCTAssertTrue(
            isServiceFailure(
                outcome(#"{"message":"slow","extensions":{"code":"QUERY_TIMEOUT"}}"#)
            )
        )
        XCTAssertTrue(isRefusal(outcome(refusal)))
        // One refusal among the errors makes it a refusal.
        XCTAssertTrue(isRefusal(outcome(internalError + "," + refusal)))
        // No code, or a code that is not text: a refusal, as before.
        XCTAssertTrue(isRefusal(outcome(#"{"message":"no code"}"#)))
        XCTAssertTrue(
            isRefusal(outcome(#"{"message":"odd","extensions":{"code":500}}"#))
        )
        XCTAssertTrue(
            isRefusal(outcome(#"{"message":"odd","extensions":"text"}"#))
        )

        XCTAssertTrue(PIIndexerError.serviceFailure.allowsOfflineFallback)
        XCTAssertTrue(PIIndexerError.serviceFailure.isWorthAnotherTry)
        XCTAssertFalse(
            PIIndexerClient.indicatesUnsupportedSchema(.serviceFailure)
        )
        XCTAssertFalse(PIIndexerError.graphQLErrors.allowsOfflineFallback)
        XCTAssertFalse(PIIndexerError.graphQLErrors.isWorthAnotherTry)
        XCTAssertTrue(
            PIIndexerClient.indicatesUnsupportedSchema(.graphQLErrors)
        )
        // The raw server text is not in the error.
        XCTAssertFalse(
            String(describing: PIIndexerError.serviceFailure).contains("db")
        )
    }

    /// The rule for showing older data, stated as two lists. Older data is
    /// shown, marked with its time, whenever PI gave no answer. It is not
    /// shown in place of an answer from PI that cannot be used.
    func testOlderDataStandsInOnlyWherePIGaveNoAnswer() throws {
        let noAnswerTransport: [URLError.Code] = [
            .timedOut, .notConnectedToInternet, .networkConnectionLost,
            .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
            .cannotLoadFromNetwork,
            // A network that intercepts TLS, or a sign-in page.
            .secureConnectionFailed, .serverCertificateUntrusted,
            .serverCertificateHasBadDate, .serverCertificateNotYetValid,
            .serverCertificateHasUnknownRoot, .userAuthenticationRequired,
            .badServerResponse, .cannotParseResponse,
        ]
        for code in noAnswerTransport {
            XCTAssertTrue(
                PIIndexerClient.allowsLastGoodValue(URLError(code)),
                "\(code.rawValue)"
            )
        }
        for code in [URLError.Code.cancelled, .badURL, .unsupportedURL,
                     .userCancelledAuthentication] {
            XCTAssertFalse(
                PIIndexerClient.allowsLastGoodValue(URLError(code)),
                "\(code.rawValue)"
            )
        }

        // A redirect, a proxy, firewall or sign-in page, an overloaded or
        // failing server.
        for status in [301, 302, 307, 401, 403, 404, 407, 408, 429, 451,
                       500, 502, 503, 504, 511] {
            XCTAssertTrue(
                PIIndexerError.httpStatus(status).allowsOfflineFallback,
                "\(status)"
            )
        }
        // PI's GraphQL endpoint refusing the request, or a success status
        // the client does not know.
        for status in [204, 206, 400, 422] {
            XCTAssertFalse(
                PIIndexerError.httpStatus(status).allowsOfflineFallback,
                "\(status)"
            )
        }
        XCTAssertTrue(PIIndexerError.foreignResponse.allowsOfflineFallback)
        for unusable in [
            PIIndexerError.invalidResponse, .invalidQuantity, .missingData,
            .invalidServiceIdentity, .invalidChainIdentity, .graphQLErrors,
            .responseTooLarge, .repeatedPage, .paginationLimit,
        ] {
            XCTAssertFalse(unusable.allowsOfflineFallback, "\(unusable)")
        }
        XCTAssertFalse(
            PIIndexerClient.allowsLastGoodValue(
                DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "")
                )
            )
        )

        // A page with status 200 that is not JSON did not come from PI.
        let html = try XCTUnwrap(
            HTTPURLResponse(
                url: PIIndexerClient.endpoint,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )
        )
        XCTAssertThrowsError(
            try PIIndexerClient.validateHTTPResponse(
                html,
                endpoint: PIIndexerClient.endpoint
            )
        ) { error in
            guard case PIIndexerError.foreignResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        // What is tried again at once: a lost or stalled request and a
        // failure on PI's side. Not "no network", and not a rate limit.
        for code in [URLError.Code.networkConnectionLost, .timedOut,
                     .secureConnectionFailed] {
            XCTAssertTrue(PIIndexerClient.isWorthAnotherTry(URLError(code)))
        }
        for code in [URLError.Code.notConnectedToInternet, .cannotFindHost,
                     .dnsLookupFailed, .cancelled] {
            XCTAssertFalse(PIIndexerClient.isWorthAnotherTry(URLError(code)))
        }
        XCTAssertTrue(PIIndexerError.httpStatus(503).isWorthAnotherTry)
        XCTAssertFalse(PIIndexerError.httpStatus(429).isWorthAnotherTry)
        XCTAssertFalse(PIIndexerError.httpStatus(403).isWorthAnotherTry)
        XCTAssertFalse(PIIndexerError.staleCheckpoint.isWorthAnotherTry)
        XCTAssertFalse(PIIndexerError.invalidResponse.isWorthAnotherTry)
    }

    // MARK: Referral rewards

    /// A reward page with a non-zero amount, captured from the live indexer
    /// on 11 October 2026 at 19:08 UTC. The amount is a whole number of the
    /// token's smallest unit, which is what the Friends screen converts.
    func testCapturedReferralRewardsWithANonZeroAmountDecodeValidateAndConvert()
        throws
    {
        let referrer = "cnX4bgFxbJZvTB86i4186415TWMuUshjxWXkvjt6QdzchhKdT"
        let page = try PIIndexerClient.decodeResponse(
            RewardsPayload.self,
            from: PIIndexerFixture.data("referrer-rewards-nonzero-page")
        ).referrerRewards

        try PIIndexerClient.validateConnectionPage(
            page,
            requestedSize: 100,
            hasPriorPage: false,
            itemIdentity: { $0.id }
        )
        // The rows are from block 28,003,025; the checkpoint of the read
        // that carried them was a little later.
        struct HealthPayload: Decodable { let _health: PIHealth }
        let health = try PIIndexerClient.decodeResponse(
            HealthPayload.self,
            from: Data(
                PIAdvancingIndexer.health(
                    indexed: 28_003_383,
                    finalized: 28_003_384,
                    indexedAt: 1_791_745_686
                ).utf8
            )
        )._health
        try PIIndexerClient.validateReferrerRewards(
            page.values,
            account: referrer,
            qualification: PIReadQualification(health: health, source: .live)
        )
        XCTAssertEqual(
            page.values.map { $0.amount?.rawValue },
            ["183330193640403131", "0"]
        )
        XCTAssertEqual(
            FriendsPresenter.rewardAmount("183330193640403131"),
            Decimal(string: "0.183330193640403131")
        )
        XCTAssertEqual(FriendsPresenter.rewardAmount("0"), 0)
    }

    /// An amount in any other form is a handled error at the client, and
    /// the conversion on the Friends screen gives 0 instead of stopping
    /// the app (`BigUInt(stringLiteral:)` traps on "0.00007").
    func testAReferralRewardThatIsNotAWholeNumberIsAHandledError() throws {
        let referrer = "cnX4bgFxbJZvTB86i4186415TWMuUshjxWXkvjt6QdzchhKdT"
        let text = try XCTUnwrap(
            String(
                data: PIIndexerFixture.data("referrer-rewards-nonzero-page"),
                encoding: .utf8
            )
        )
        let amount = #""amount":"183330193640403131""#
        XCTAssertTrue(text.contains(amount))
        for other in [#""amount":"0.00007""#, #""amount":0.00007"#,
                      #""amount":"1.0""#] {
            let page = try PIIndexerClient.decodeResponse(
                RewardsPayload.self,
                from: Data(
                    text.replacingOccurrences(of: amount, with: other).utf8
                )
            ).referrerRewards
            XCTAssertThrowsError(
                try PIIndexerClient.validateReferrerRewards(
                    page.values,
                    account: referrer,
                    qualification: nil
                ),
                other
            ) { error in
                guard case PIIndexerError.invalidQuantity = error else {
                    return XCTFail("\(other): \(error)")
                }
            }
        }
        for text in ["0.00007", "", "-1", "1e3", "12 ", "abc", "٣"] {
            XCTAssertEqual(FriendsPresenter.rewardAmount(text), 0, text)
        }
    }

    // MARK: Catalog size

    /// The market data request accepts as many assets as the catalog walk
    /// can return.
    func testMarketDataAcceptsAsManyAssetsAsTheCatalogWalkReturns() throws {
        XCTAssertEqual(PIIndexerClient.maximumCatalogPages, 100)
        XCTAssertEqual(
            PIMarketCapCatalogValidator.maximumRequestedAssetCount,
            PIIndexerClient.maximumCatalogPages * 100
        )
        XCTAssertNoThrow(
            try PIMarketCapCatalogValidator.validatedRequestedAssetIDs(
                (0 ..< 2_500).map { "asset-\($0)" }
            )
        )
    }
}

// MARK: - Review round 4: a walk survives a lost request

extension PIIndexerAdvancingReadTests {
    private func lost(
        _ code: URLError.Code
    ) -> PIStubIndexerProtocol.Response {
        .init(body: "", transportError: code)
    }

    /// One request of a walk is lost on the way (a mobile network; request
    /// 14 of 21 in the review). Only that page is asked for again; the
    /// pages already read are kept and the walk completes. Before, every
    /// page was thrown away and prices stayed away for 20 s or more.
    func testAPageLostOnTheWayIsAskedForAgainAndTheWalkCompletes()
        async throws
    {
        for code in [URLError.Code.networkConnectionLost, .timedOut] {
            pauses = []
            let indexer = try indexer()
            indexer.heightForHealthRead = { _, height in height + 1 }
            indexer.answerForPageRead = { [unowned self] read in
                read == 2 ? self.lost(code) : nil
            }

            let read = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )

            XCTAssertEqual(read.value.count, 8, "\(code.rawValue)")
            XCTAssertEqual(Set(read.value.map(\.id)).count, 8)
            XCTAssertEqual(read.qualification?.source, .live)
            // Three pages, and the second one once more. The first page
            // was not read again.
            XCTAssertEqual(pageReads(), 4, "\(code.rawValue)")
            XCTAssertEqual(pauses.count, 1, "\(code.rawValue)")
        }
    }

    /// The same when the request that is lost is the health read after a
    /// page: that page is read again, with its two health reads.
    func testAHealthReadLostInTheMiddleOfAWalkCostsOnePageNotTheWalk()
        async throws
    {
        let indexer = try indexer()
        indexer.answerForHealthRead = { [unowned self] read in
            read == 3 ? self.lost(.networkConnectionLost) : nil
        }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(read.qualification?.source, .live)
        XCTAssertEqual(pageReads(), 4)
        // Before page 1, after pages 1 and 2 (lost), after page 2 again,
        // after page 3.
        XCTAssertEqual(healthReads(), 5)
        XCTAssertEqual(pauses.count, 1)
    }

    /// The retry is bounded per walk: two more tries, then the walk ends
    /// with the transport error (and the store shows the last good
    /// catalog).
    func testAPageThatKeepsGettingLostEndsTheWalkAfterTwoMoreTries()
        async throws
    {
        let indexer = try indexer()
        indexer.answerForPageRead = { [unowned self] read in
            read >= 2 ? self.lost(.networkConnectionLost) : nil
        }

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A walk whose second page never arrives completed")
        } catch {
            XCTAssertEqual(
                (error as? URLError)?.code,
                .networkConnectionLost,
                "\(error)"
            )
        }
        XCTAssertEqual(
            pageReads(),
            2 + PIIndexerClient.maximumTransientRetries
        )
        XCTAssertEqual(pauses.count, PIIndexerClient.maximumTransientRetries)
    }

    /// A timeout has already cost 20 s: after pages were read it gets one
    /// more try, not two.
    func testATimeoutIsTriedOnceMoreAndNotAgain() async throws {
        let indexer = try indexer()
        indexer.answerForPageRead = { [unowned self] read in
            read >= 2 ? self.lost(.timedOut) : nil
        }

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A walk whose pages time out completed")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut, "\(error)")
        }
        // Page 1, page 2, page 2 once more.
        XCTAssertEqual(pageReads(), 3)
        XCTAssertEqual(pauses.count, 1)
    }

    /// A timeout before anything was read is what "no connection" looks
    /// like on a session that waits for one. It is not tried again, so the
    /// saved copy is not kept waiting behind a second timeout.
    func testATimeoutBeforeAnythingWasReadIsNotTriedAgain() async throws {
        let indexer = try indexer()
        indexer.answerForPageRead = { [unowned self] _ in
            self.lost(.timedOut)
        }

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A walk whose pages time out completed")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut, "\(error)")
        }
        XCTAssertEqual(pageReads(), 1)
        XCTAssertTrue(pauses.isEmpty)
    }

    /// With no network nothing is asked twice: the store has its own
    /// schedule, and the screens must not wait for retries that cannot
    /// succeed.
    func testWithNoNetworkNothingIsAskedTwice() async throws {
        let indexer = try indexer()
        indexer.answerForHealthRead = { [unowned self] _ in
            self.lost(.notConnectedToInternet)
        }

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("A walk without a network completed")
        } catch {
            XCTAssertEqual(
                (error as? URLError)?.code,
                .notConnectedToInternet,
                "\(error)"
            )
        }
        XCTAssertEqual(healthReads(), 1)
        XCTAssertEqual(pageReads(), 0)
        XCTAssertTrue(pauses.isEmpty)
    }

    private static let internalServerError =
        #"{"errors":[{"message":"database error","path":["assets"],"extensions":{"code":"INTERNAL_SERVER_ERROR"}}],"data":null}"#

    /// A database error on one of the pages (HTTP 200 with
    /// `INTERNAL_SERVER_ERROR`): the page is asked for again and the walk
    /// completes.
    func testAFailureOnPIsSideOnOnePageIsTriedAgain() async throws {
        let indexer = try indexer()
        indexer.answerForPageRead = { read in
            read == 2
                ? PIStubIndexerProtocol.Response(body: Self.internalServerError)
                : nil
        }

        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.value.count, 8)
        XCTAssertEqual(read.qualification?.source, .live)
        XCTAssertEqual(pageReads(), 4)
    }

    /// When PI keeps failing on its side, that is "PI cannot be read right
    /// now", not "PI refused the query": the last good catalog is used.
    /// Before, the catalog was hidden and the wallet read "Price
    /// unavailable" although it held prices a few minutes old.
    func testAPIThatKeepsFailingOnItsSideGivesTheLastGoodCatalog()
        async throws
    {
        let indexer = try indexer()
        let good = try await client().allAssets(pageSize: 3, maximumPages: 5)

        indexer.answerForPageRead = { _ in
            PIStubIndexerProtocol.Response(body: Self.internalServerError)
        }
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }
        let read = try await client().qualifiedAllAssets(
            pageSize: 3,
            maximumPages: 5
        )

        XCTAssertEqual(read.qualification?.source, .cache)
        XCTAssertEqual(read.value, good)
        XCTAssertEqual(
            pageReads(),
            1 + PIIndexerClient.maximumTransientRetries
        )
    }

    /// Something between the phone and PI answered in PI's place: a Wi-Fi
    /// sign-in page, a firewall, a network that intercepts TLS. The last
    /// good catalog is used. Before, each of these hid it.
    func testAnAnswerThatDidNotComeFromPIGivesTheLastGoodCatalog()
        async throws
    {
        let answers: [(String, PIStubIndexerProtocol.Response)] = [
            (
                "a sign-in page with status 200",
                .init(body: "<html>Sign in</html>", contentType: "text/html")
            ),
            (
                "403 from a firewall",
                .init(
                    status: 403,
                    body: "<html>Forbidden</html>",
                    contentType: "text/html"
                )
            ),
            ("404", .init(status: 404, body: "{}")),
            ("a redirect", .init(status: 302, body: "")),
            ("TLS that cannot be established", lost(.secureConnectionFailed)),
            ("an untrusted certificate", lost(.serverCertificateUntrusted)),
        ]
        for (name, answer) in answers {
            let indexer = try indexer()
            let good = try await client().allAssets(
                pageSize: 3,
                maximumPages: 5
            )

            indexer.answerForHealthRead = { _ in answer }
            indexer.answerForPageRead = { _ in answer }
            PIStubIndexerProtocol.install { indexer.respond(to: $0) }
            let read = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )

            XCTAssertEqual(read.qualification?.source, .cache, name)
            XCTAssertEqual(read.value, good, name)
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
    }

    /// The asset catalog has more than 2,000 rows one day (registering an
    /// asset needs no permission). The walk used to stop at 20 pages with
    /// an error that also hid the last good catalog: no price anywhere,
    /// for every user, until an app update. It now reads up to 100 pages.
    func testTheCatalogWalkGoesPastTwentyPages() async throws {
        let rows = try PIIndexerFixture.assetRows()
        let xor =
            "0x0200000000000000000000000000000000000000000000000000000000000000"
        let template = try XCTUnwrap(rows.first { $0.contains(xor) })
        let many = (0 ..< 25).map { index in
            template.replacingOccurrences(
                of: xor,
                with: "0x02" + String(format: "%062d", index)
            )
        }
        let indexer = PIAdvancingIndexer(assetRows: many)
        PIStubIndexerProtocol.install { indexer.respond(to: $0) }

        // One row per page, with the number of pages the app uses.
        let read = try await client().qualifiedAllAssets(pageSize: 1)

        XCTAssertEqual(read.value.count, 25)
        XCTAssertEqual(Set(read.value.map(\.id)).count, 25)
        XCTAssertEqual(pageReads(), 25)
    }
}

// MARK: - Review round 4: the store keeps its catalog when PI gave no answer

extension PICatalogStoreTests {
    /// The store with the app's own rule (`PIIndexerClient
    /// .allowsLastGoodValue`). After a live read, a refresh fails because
    /// PI gave no answer; the catalog held is shown with its time. Each of
    /// these used to hide it, so the wallet lost every fiat value.
    func testTheCatalogHeldIsShownWhenPIGaveNoAnswer() async throws {
        let failures: [Swift.Error] = [
            PIIndexerError.serviceFailure,
            PIIndexerError.foreignResponse,
            PIIndexerError.httpStatus(403),
            PIIndexerError.httpStatus(404),
            URLError(.secureConnectionFailed),
            URLError(.serverCertificateUntrusted),
            URLError(.badServerResponse),
        ]
        for failure in failures {
            let source = Source()
            let store = store(source, freshFor: 600)
            let loadedAt = wallClock(source)
            _ = try await store.values()

            source.advance(720)
            source.result = .failure(failure)
            _ = try await store.snapshot()
            await store.settled()

            let shown = try await store.snapshot()
            XCTAssertEqual(shown.values, ["a"], "\(failure)")
            XCTAssertEqual(shown.asOf, loadedAt, "\(failure)")
        }
    }
}

// MARK: - Review round 4: prices, market data and the screens that show them

/// A price service whose answer the test changes.
private actor SwitchableFiat: FiatServiceProtocol {
    private var data: [PIExactFiatData]
    private(set) var calls = 0

    init(_ data: [PIExactFiatData]) {
        self.data = data
    }

    func set(_ data: [PIExactFiatData]) {
        self.data = data
    }

    func getFiat() async -> [PIExactFiatData] {
        calls += 1
        return data
    }
}

/// The send-amount screen as the view model sees it.
private final class SendAmountTestView: InputAssetAmountViewProtocol {
    private let lock = NSLock()
    private var balances: [String] = []
    private var fiatTexts: [String] = []
    private var offMainThread = 0
    private var button: Bool?
    let controller: UIViewController

    /// Every balance text the screen was given, in order.
    var balanceTexts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return balances
    }

    /// How many times the balance label was written from a thread other
    /// than the main one.
    var balanceWritesOffMainThread: Int {
        lock.lock()
        defer { lock.unlock() }
        return offMainThread
    }

    /// Whether the button to go on was last switched on.
    var buttonEnabled: Bool? {
        lock.lock()
        defer { lock.unlock() }
        return button
    }

    init(controller: UIViewController) {
        self.controller = controller
    }

    var isSetup: Bool { true }

    var balanceText: String? {
        lock.lock()
        defer { lock.unlock() }
        return balances.last
    }

    var fiatText: String? {
        lock.lock()
        defer { lock.unlock() }
        return fiatTexts.last
    }

    func updateFirstAsset(balance: String) {
        lock.lock()
        balances.append(balance)
        if !Thread.isMainThread {
            offMainThread += 1
        }
        lock.unlock()
    }

    func updateFirstAsset(fiatText: String) {
        lock.lock()
        fiatTexts.append(fiatText)
        lock.unlock()
    }

    func updateFirstAsset(symbol _: String, image _: UIImage?) {}
    func updateRecipientView(with _: String) {}
    func updateFirstAsset(state _: InputFieldState, amountColor _: SoramitsuColor, fiatColor _: SoramitsuColor) {}
    func set(firstAmountText _: String) {}
    func setupButton(isEnabled: Bool) {
        lock.lock()
        button = isEnabled
        lock.unlock()
    }
    func focusFirstField() {}
    func updateWarinignView(model _: WarningViewModel) {}
}

final class PIRound4PriceTests: XCTestCase {
    private static let eth =
        "0x0200070000000000000000000000000000000000000000000000000000000000"

    private func wait(
        _ what: String,
        until condition: @escaping () -> Bool
    ) async {
        for _ in 0 ..< 500 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    private func asset(
        _ id: String,
        price: String,
        change: Double,
        liquidity: String
    ) throws -> PIAsset {
        PIAsset(
            id: id,
            priceUSD: try PIQuantity(price),
            liquidity: try PIQuantity(liquidity),
            priceChangeDay: change
        )
    }

    private func capturedCatalog() throws -> [PIAsset] {
        struct Payload: Decodable {
            let assets: PIConnection<PIAsset>
        }
        return try PIIndexerClient.decodeResponse(
            Payload.self,
            from: PIIndexerFixture.data("assets-page")
        ).assets.values
    }

    // MARK: Market data

    /// A cold start the morning after: the store answers at once with the
    /// catalog saved yesterday (VAL +75.25%) and reads PI behind the
    /// caller. When the live catalog is there (VAL -40%), the next answer
    /// of the production price service carries the live 24-hour change and
    /// liquidity. Before, `MarketCapService` kept the first answer for ten
    /// minutes: yesterday's change stood next to today's prices, with no
    /// "Prices as of" line to say so.
    func testTheDayChangeFollowsTheCatalogFromTheSavedOneToTheLiveOne()
        async throws
    {
        let yesterday = [
            try asset(priceTestXor, price: "5", change: -10.5, liquidity: "1000000000000000000"),
            try asset(priceTestVal, price: "0.02", change: 75.25, liquidity: "2000000000000000000"),
        ]
        let today = [
            try asset(priceTestXor, price: "6", change: 3.5, liquidity: "3000000000000000000"),
            try asset(priceTestVal, price: "0.01", change: -40, liquidity: "4000000000000000000"),
        ]
        let liveRead = TestGate()
        let savedAt = Date().addingTimeInterval(-13 * 3_600)
        let store = PICatalogStore<PIAsset>(
            freshFor: 600,
            staleFor: 1_800,
            saved: {
                PIQualifiedRead(
                    value: yesterday,
                    qualification: nil,
                    savedAt: savedAt
                )
            },
            load: {
                await liveRead.passed()
                return PIQualifiedRead(value: today, qualification: nil)
            }
        )
        let service = PriceInfoService(
            fiatService: FiatService(catalog: { try await store.snapshot() }),
            marketCapService: MarketCapService(
                catalog: { try await store.values() }
            )
        )
        let ids = [priceTestXor, priceTestVal]
        func val(_ info: PriceInfo) -> MarketCapInfo? {
            info.marketCapInfo.first { $0.assetId == priceTestVal }
        }

        let first = await service.getPriceInfo(for: ids)
        XCTAssertEqual(first.pricesAsOf, savedAt)
        XCTAssertEqual(val(first)?.hourDelta, Decimal(75.25))
        XCTAssertEqual(val(first)?.liquidity, 2)

        liveRead.open()
        await store.settled()

        let second = await service.getPriceInfo(for: ids)
        XCTAssertNil(second.pricesAsOf)
        XCTAssertEqual(
            second.fiatData.first { $0.id == priceTestVal }?.priceUsd?.rawValue,
            "0.01"
        )
        XCTAssertEqual(
            val(second)?.hourDelta,
            Decimal(-40),
            "Yesterday's 24-hour change is shown next to today's price"
        )
        XCTAssertEqual(val(second)?.liquidity, 4)
        XCTAssertEqual(
            second.marketCapInfo.first { $0.assetId == priceTestXor }?.hourDelta,
            Decimal(3.5)
        )
    }

    /// The service answers for exactly the assets asked for, each time
    /// from the catalog as it is at that moment.
    func testMarketDataIsWorkedOutFromTheCatalogOnEveryCall() async throws {
        let prices = SwitchablePrices()
        prices.set([
            try asset(priceTestXor, price: "5", change: 1, liquidity: "1000000000000000000"),
            try asset(priceTestVal, price: "1", change: 2, liquidity: "1000000000000000000"),
        ])
        let service = MarketCapService(catalog: { try prices.assets() })

        let both = await service.getMarketCap(for: [priceTestXor, priceTestVal])
        XCTAssertEqual(Set(both.map(\.assetId)), [priceTestXor, priceTestVal])
        let one = await service.getMarketCap(for: [priceTestXor])
        XCTAssertEqual(one.map(\.assetId), [priceTestXor])
        XCTAssertEqual(one.first?.hourDelta, 1)

        prices.set([
            try asset(priceTestXor, price: "5", change: -8, liquidity: "5000000000000000000"),
        ])
        let later = await service.getMarketCap(for: [priceTestXor])
        XCTAssertEqual(later.first?.hourDelta, -8)
        XCTAssertEqual(later.first?.liquidity, 5)
    }

    // MARK: A price of zero

    /// The captured page has bridged ETH at a price of "0" although it has
    /// liquidity. That is "PI could not price it", which the screens show
    /// like a missing price.
    func testAPublishedPriceOfZeroIsNoPrice() async throws {
        let catalog = try capturedCatalog()
        XCTAssertEqual(
            catalog.first { $0.id == Self.eth }?.priceUSD?.rawValue,
            "0"
        )

        let fiat = await FiatService(assets: { catalog }).getFiat()

        XCTAssertEqual(fiat.count, catalog.count)
        let eth = try XCTUnwrap(fiat.first { $0.id == Self.eth })
        XCTAssertNil(eth.priceUsd)
        XCTAssertEqual(
            fiat.first { $0.id == priceTestXor }?.priceUsd?.rawValue,
            "5.40462719"
        )
        XCTAssertTrue(try PIQuantity("0").isZero)
        XCTAssertTrue(try PIQuantity("0.000").isZero)
        XCTAssertTrue(try PIQuantity("-0.0").isZero)
        XCTAssertFalse(try PIQuantity("0.00000102").isZero)
        XCTAssertFalse(try PIQuantity("10").isZero)
    }

    private func wallet(
        holding balances: [BalanceData],
        prices: PriceInfo
    ) -> (AssetsItemService, [Any]) {
        let assets = [
            AssetInfo(id: priceTestXor, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: Self.eth, symbol: "ETH", chainId: "", precision: 18, icon: nil, displayName: "Ether", visible: true),
        ]
        let manager = PriceTestAssetManager(assets: assets)
        let provider = PriceTestAssetProvider(balances: balances)
        let priceInfo = PriceTestPriceInfo()
        priceInfo.info = prices
        let service = AssetsItemService(
            marketCapService: PriceTestMarketCap(),
            fiatService: nil,
            assetViewModelsFactory: AssetViewModelFactory(
                walletAssets: assets,
                assetManager: manager,
                fiatService: nil
            ),
            assetManager: manager,
            assetProvider: provider,
            priceInfoService: priceInfo
        )
        return (service, [manager, provider, priceInfo])
    }

    /// The wallet through its production service, with the prices the
    /// production price service makes of the captured page. A wallet that
    /// holds only ETH read "$0" in total and "$0" on the row.
    func testAWalletHoldingOnlyAnUnpricedAssetDoesNotReadZero() async throws {
        let fiat = await FiatService(assets: { [self] in
            try capturedCatalog()
        }).getFiat()
        let prices = PriceInfo(fiatData: fiat, marketCapInfo: [])

        // Only ETH: the value is not known.
        let (onlyEth, keptA) = wallet(
            holding: [
                BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: 0)),
                BalanceData(identifier: Self.eth, balance: AmountDecimal(value: 2)),
            ],
            prices: prices
        )
        onlyEth.setup()
        // The service writes the total and then the rows: wait for both.
        await wait("the total and its rows") {
            !onlyEth.moneyText.isEmpty &&
                onlyEth.assetViewModels.allSatisfy(\.priceLoadFinished)
        }
        XCTAssertEqual(onlyEth.moneyText, WalletUX.priceUnavailableText)
        XCTAssertTrue(onlyEth.priceIsUnavailable)
        // The prices were read; asking again would change nothing.
        XCTAssertFalse(onlyEth.hasScheduledPriceRetry)
        let ethRow = try XCTUnwrap(
            onlyEth.assetViewModels.first { $0.identifier == Self.eth }
        )
        XCTAssertEqual(ethRow.fiatText, "")
        XCTAssertTrue(ethRow.priceLoadFinished)

        // XOR and ETH: the total is the part that has a price.
        let (mixed, keptB) = wallet(
            holding: [
                BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: 100)),
                BalanceData(identifier: Self.eth, balance: AmountDecimal(value: 2)),
            ],
            prices: prices
        )
        mixed.setup()
        await wait("the total") { !mixed.moneyText.isEmpty }
        XCTAssertEqual(mixed.moneyText, "$540.46")
        XCTAssertFalse(mixed.priceIsUnavailable)
        XCTAssertEqual(
            mixed.assetViewModels.first { $0.identifier == Self.eth }?.fiatText,
            ""
        )

        // Nothing held: "$0" is the truth.
        let (empty, keptC) = wallet(
            holding: [
                BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: 0)),
                BalanceData(identifier: Self.eth, balance: AmountDecimal(value: 0)),
            ],
            prices: prices
        )
        empty.setup()
        await wait("the total") { !empty.moneyText.isEmpty }
        XCTAssertEqual(empty.moneyText, "$0")
        XCTAssertFalse(empty.priceIsUnavailable)
        withExtendedLifetime((keptA, keptB, keptC)) {}
    }

    func testPooledTotalIsUnknownWhenNoPositionHasAPrice() throws {
        let prices = [
            PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity("5")),
            PIExactFiatData(id: priceTestVal, priceUsd: try PIQuantity("1")),
            PIExactFiatData(id: Self.eth, priceUsd: nil),
        ]
        func position(_ target: String, pooled: Decimal) -> PoolInfo {
            PoolInfo(
                baseAssetId: priceTestXor,
                targetAssetId: target,
                poolId: "pool-\(target)",
                isFavorite: true,
                accountId: "",
                baseAssetPooledByAccount: pooled,
                targetAssetPooledByAccount: pooled
            )
        }

        XCTAssertFalse(PoolsItemService.pricesKnown(for: [], fiatData: []))
        XCTAssertTrue(PoolsItemService.pricesKnown(for: [], fiatData: prices))
        XCTAssertTrue(
            PoolsItemService.pricesKnown(
                for: [position(priceTestVal, pooled: 3)],
                fiatData: prices
            )
        )
        XCTAssertFalse(
            PoolsItemService.pricesKnown(
                for: [position(Self.eth, pooled: 3)],
                fiatData: prices
            )
        )
        XCTAssertTrue(
            PoolsItemService.pricesKnown(
                for: [
                    position(Self.eth, pooled: 3),
                    position(priceTestVal, pooled: 1),
                ],
                fiatData: prices
            )
        )
        // A position with nothing in it has a value: zero.
        XCTAssertTrue(
            PoolsItemService.pricesKnown(
                for: [position(Self.eth, pooled: 0)],
                fiatData: prices
            )
        )
    }

    // MARK: Screens that asked for prices once

    private func assets() -> [AssetInfo] {
        [
            AssetInfo(id: priceTestXor, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
            AssetInfo(id: priceTestVal, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "SORA Validator Token", visible: true),
        ]
    }

    private func xor(at price: String) throws -> [PIExactFiatData] {
        [PIExactFiatData(id: priceTestXor, priceUsd: try PIQuantity(price))]
    }

    /// Send: the user opens the screen within the seconds the walk takes,
    /// so the first prices are yesterday's ($2). When the live catalog
    /// arrives ($3) the value under the amount and the balance follow.
    /// Before, they stayed at yesterday's price while the screen was open.
    func testSendAmountFollowsThePricesWhenTheLiveCatalogArrives()
        async throws
    {
        let fiat = SwitchableFiat(try xor(at: "2"))
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: [
            BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: 100)),
        ])
        let network = WalletNetworkOperationFactoryProtocolMock()
        let viewModel = InputAssetAmountViewModel(
            selectedTokenId: priceTestXor,
            selectedAddress: "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy",
            fiatService: fiat,
            assetManager: manager,
            providerFactory: BalanceProviderFactory(
                accountId: "",
                cacheFacade: CoreDataCacheFacade.shared,
                networkOperationFactory: network,
                identifierFactory: SingleProviderIdentifierFactory()
            ),
            networkFacade: network,
            wireframe: InputAssetAmountWireframe(),
            assetsProvider: provider,
            qrEncoder: ActionTestQREncoder(),
            sharingFactory: ActionTestShareFactory(),
            marketCapService: PriceTestMarketCap()
        )
        let view = await MainActor.run {
            SendAmountTestView(controller: UIViewController())
        }
        await MainActor.run {
            viewModel.view = view
            viewModel.viewDidLoad()
        }
        await wait("the balance at the first price") {
            view.balanceText == "100 ($200)"
        }
        await MainActor.run { viewModel.inputedFirstAmount = 2 }
        await wait("the value at the first price") { view.fiatText == "$4" }

        await fiat.set(try xor(at: "3"))
        NotificationCenter.default.post(
            name: PICatalogs.pricesDidChange,
            object: nil
        )

        await wait("the value at the live price") { view.fiatText == "$6" }
        await wait("the balance at the live price") {
            view.balanceText == "100 ($300)"
        }
        withExtendedLifetime((fiat, manager, provider, view)) {}
    }

    /// Review round 6, finding 6. XOR could not be read (a runtime upgrade
    /// renamed a field of `System.Account`). The send-amount screen wrote
    /// "Balance unavailable" once and kept a zero placeholder as the
    /// balance: the first price answer put "0 ($0)" in its place, any
    /// amount typed was "not enough balance", and the notice was written
    /// to the label from the balance provider's queue.
    func testSendAmountKeepsBalanceUnavailableWhenPricesArrive() async throws {
        let fiat = SwitchableFiat(try xor(at: "2"))
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: [], unavailable: [priceTestXor])
        let network = WalletNetworkOperationFactoryProtocolMock()
        let viewModel = InputAssetAmountViewModel(
            selectedTokenId: priceTestXor,
            selectedAddress: "cnRWUatULzf8AVfKVexXMKJx9bT9UeTEM4wmWG7B7g1cxVjXy",
            fiatService: fiat,
            assetManager: manager,
            providerFactory: BalanceProviderFactory(
                accountId: "",
                cacheFacade: CoreDataCacheFacade.shared,
                networkOperationFactory: network,
                identifierFactory: SingleProviderIdentifierFactory()
            ),
            networkFacade: network,
            wireframe: InputAssetAmountWireframe(),
            assetsProvider: provider,
            qrEncoder: ActionTestQREncoder(),
            sharingFactory: ActionTestShareFactory(),
            marketCapService: PriceTestMarketCap()
        )
        let view = await MainActor.run {
            SendAmountTestView(controller: UIViewController())
        }
        await MainActor.run {
            viewModel.view = view
            viewModel.viewDidLoad()
        }
        let notice = WalletUX.balanceUnavailableText
        await wait("the notice in place of the balance") { view.balanceText == notice }

        // The prices answer ($2 per XOR). The notice stays; before, the
        // label became "0 ($0)".
        for _ in 0 ..< 500 {
            if await fiat.calls >= 1 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        await MainActor.run { viewModel.inputedFirstAmount = 2 }
        await wait("the value of the amount typed") { view.fiatText == "$4" }
        XCTAssertEqual(view.balanceText, notice)
        XCTAssertEqual(Set(view.balanceTexts), [notice])
        // No "not enough balance" from a balance that is not known, and
        // nothing to review either.
        XCTAssertNotEqual(
            view.fiatText,
            R.string.localizable.commonNotEnoughBalance(preferredLanguages: .currentLocale)
        )
        XCTAssertEqual(view.buttonEnabled, false)
        XCTAssertTrue(viewModel.firstAssetBalanceUnavailable)

        // New prices while the screen is open: still the notice.
        await fiat.set(try xor(at: "3"))
        NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil)
        await wait("the value at the new price") { view.fiatText == "$6" }
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(Set(view.balanceTexts), [notice])
        XCTAssertEqual(view.buttonEnabled, false)

        // The balance is read. The provider tells its observers on its own
        // queue; the screen is written on the main thread.
        let read = BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: 100))
        provider.balances = [read]
        provider.unavailable = []
        DispatchQueue.global().async { viewModel.processBalance(data: [read]) }
        await wait("the balance in place of the notice") { view.balanceText == "100 ($300)" }
        await wait("the amount can be reviewed") { view.buttonEnabled == true }
        XCTAssertFalse(viewModel.firstAssetBalanceUnavailable)

        // And unavailable again on the next read, also from that queue.
        provider.balances = []
        provider.unavailable = [priceTestXor]
        DispatchQueue.global().async { viewModel.processBalance(data: []) }
        await wait("the notice again") { view.balanceText == notice }
        await wait("nothing to review again") { view.buttonEnabled == false }
        XCTAssertEqual(view.fiatText, "$6")
        XCTAssertEqual(view.balanceWritesOffMainThread, 0)
        withExtendedLifetime((fiat, manager, provider, view)) {}
    }

    /// The same for "request an amount".
    func testRequestAmountFollowsThePricesWhenTheLiveCatalogArrives()
        async throws
    {
        let fiat = SwitchableFiat(try xor(at: "2"))
        let manager = PriceTestAssetManager(assets: assets())
        let provider = PriceTestAssetProvider(balances: [
            BalanceData(identifier: priceTestXor, balance: AmountDecimal(value: 100)),
        ])
        let viewModel = InputSendInfoViewModel(
            address: "",
            accountId: "00",
            username: "",
            fiatService: fiat,
            assetManager: manager,
            assetsProvider: provider,
            wireframe: nil,
            qrEncoder: ActionTestQREncoder(),
            sharingFactory: ActionTestShareFactory(),
            marketCapService: PriceTestMarketCap()
        )

        viewModel.viewDidLoad()
        viewModel.inputedAmount = 2
        await wait("the value at the first price") {
            viewModel.inputedFiatAmountText == "$4"
        }
        XCTAssertEqual(viewModel.balanceFiatText, "100 ($200)")

        await fiat.set(try xor(at: "3"))
        NotificationCenter.default.post(
            name: PICatalogs.pricesDidChange,
            object: nil
        )

        await wait("the value at the live price") {
            viewModel.inputedFiatAmountText == "$6"
        }
        XCTAssertEqual(viewModel.balanceFiatText, "100 ($300)")
        let calls = await fiat.calls
        XCTAssertEqual(calls, 2)
        withExtendedLifetime((fiat, manager, provider)) {}
    }

    /// The observation ends with the screen that holds it.
    func testAScreenThatIsGoneIsNotToldAboutPrices() {
        let told = Counter()
        var observation: PIPricesObservation? = PIPricesObservation {
            told.increment()
        }
        NotificationCenter.default.post(
            name: PICatalogs.pricesDidChange,
            object: nil
        )
        XCTAssertEqual(told.value, 1)
        XCTAssertNotNil(observation)

        observation = nil
        NotificationCenter.default.post(
            name: PICatalogs.pricesDidChange,
            object: nil
        )
        XCTAssertEqual(told.value, 1)
    }
}

// MARK: - Review round 4: Activity keeps saved and current pages apart

private struct ActivityTestTransaction: Transaction {
    var base: TransactionBase

    init(_ hash: String, day: String) {
        base = TransactionBase(
            txHash: hash,
            blockHash: "",
            fee: Amount(value: 0),
            status: .success,
            timestamp: day
        )
    }
}

/// One section per page, named after the day of its first row.
private final class ActivityTestFactory: ActivityViewModelFactoryProtocol {
    var currentDate: Date?

    func createActivityViewModels(
        with transactions: [Transaction],
        tapHandler _: @escaping (Transaction) -> Void
    ) -> [ActivitySection] {
        guard let first = transactions.first else { return [] }
        return [
            ActivitySection(
                date: first.base.timestamp,
                items: transactions.map {
                    .activity(
                        ActivityItem(
                            model: ActivityContentViewModel(
                                txHash: $0.base.txHash,
                                title: "Sent",
                                subtitle: $0.base.txHash,
                                fiatText: "$1"
                            )
                        )
                    )
                }
            ),
        ]
    }

    func createActivityShimmerModels() -> [ActivitySection] { [] }

    func createActivityViewModel(
        with transaction: Transaction
    ) -> ActivityContentViewModel? {
        ActivityContentViewModel(txHash: transaction.base.txHash)
    }
}

private final class ActivityTestHistory: HistoryServiceProtocol {
    private let lock = NSLock()
    private var pages: [Int: HistoryPage] = [:]
    private var failures: [Int: Swift.Error] = [:]
    private var asked: [Int] = []
    private var askedAssets: [String?] = []
    private var gate: TestGate?

    func set(_ page: Int, _ value: HistoryPage?) {
        lock.lock()
        pages[page] = value
        failures[page] = nil
        lock.unlock()
    }

    /// The page fails with this error instead of HTTP 503.
    func fail(_ page: Int, with error: Swift.Error) {
        lock.lock()
        pages[page] = nil
        failures[page] = error
        lock.unlock()
    }

    /// Requests made from now on are answered when the gate is opened,
    /// with the answer set at that time.
    func hold() -> TestGate {
        let held = TestGate()
        lock.lock()
        gate = held
        lock.unlock()
        return held
    }

    var requests: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return asked
    }

    var requestedAssets: [String?] {
        lock.lock()
        defer { lock.unlock() }
        return askedAssets
    }

    private func note(_ page: Int, assetId: String?) -> TestGate? {
        lock.lock()
        defer { lock.unlock() }
        asked.append(page)
        askedAssets.append(assetId)
        return gate
    }

    private func answer(_ page: Int) -> Result<HistoryPage, Swift.Error> {
        lock.lock()
        defer { lock.unlock() }
        if let value = pages[page] {
            return .success(value)
        }
        return .failure(failures[page] ?? PIIndexerError.httpStatus(503))
    }

    func getPageHistory(
        count _: Int,
        page: Int,
        assetId: String?
    ) async throws -> HistoryPage {
        await note(page, assetId: assetId)?.passed()
        return try answer(page).get()
    }

    func getHistory(count _: Int, assetId _: String?) async throws -> [Transaction] { [] }
    func getTransaction(by _: String) -> Transaction? { nil }

    func getHistory(
        count _: Int,
        assetId _: String?,
        completion: @escaping (Result<[Transaction], Swift.Error>) -> Void
    ) {
        completion(.success([]))
    }

    func getPageHistory(
        count _: Int,
        page _: Int,
        assetId _: String?,
        completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void
    ) {
        completion(.failure(PIIndexerError.httpStatus(503)))
    }
}

private final class ActivityTestEvents: EventCenterProtocol {
    func notify(with _: EventProtocol) {}
    func notify(with _: EventProtocol, completionOnMain: @escaping () -> Void) {
        completionOnMain()
    }
    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

private final class ActivityPagingTestView: ActivityViewProtocol {
    let controller = UIViewController()
    var isSetup: Bool { true }
    private(set) var isPaginating = false
    private(set) var paginationStops = 0

    func stopAnimating() {}
    func resetPagination() {}
    func startPaginationLoader() { isPaginating = true }
    func stopPaginationLoader() {
        isPaginating = false
        paginationStops += 1
    }
}

/// What the list of a view model holds, row by row.
private enum ActivityTestList {
    static func rows(_ viewModel: ActivityViewModel) -> [String] {
        viewModel.sections.flatMap(\.items).compactMap { item in
            if case let .activity(activity) = item {
                return activity.model.txHash
            }
            return nil
        }
    }

    static func notices(_ viewModel: ActivityViewModel) -> [String] {
        viewModel.sections.flatMap(\.items).compactMap { item in
            if case let .notice(notice) = item {
                return notice.text
            }
            return nil
        }
    }

    /// "Some data is not up to date / Refresh" rows.
    static func retryRows(_ viewModel: ActivityViewModel) -> Int {
        viewModel.sections.flatMap(\.items).filter { item in
            if case let .error(row) = item { return row.title == nil }
            return false
        }.count
    }

    /// The texts of the "Activity as of ... / Refresh" rows.
    static func refreshRows(_ viewModel: ActivityViewModel) -> [String] {
        viewModel.sections.flatMap(\.items).compactMap { item in
            if case let .error(row) = item { return row.title }
            return nil
        }
    }

    /// The rows the screen was last told to draw.
    static func drawnRows(_ viewModel: ActivityViewModel) -> [String] {
        viewModel.snapshot.itemIdentifiers.compactMap { item in
            if case let .activity(activity) = item {
                return activity.model.txHash
            }
            return nil
        }
    }
}

final class PIRound4ActivityTests: XCTestCase {
    @MainActor
    private func wait(
        _ what: String,
        until condition: @escaping () -> Bool
    ) async {
        for _ in 0 ..< 500 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    private func page(
        _ hashes: [String],
        day: String,
        cachedAt: Date? = nil,
        endReached: Bool = false
    ) -> HistoryPage {
        HistoryPage(
            transactions: hashes.map { ActivityTestTransaction($0, day: day) },
            endReached: endReached,
            cachedAt: cachedAt
        )
    }

    /// These tests are about pages: the list does not ask again by itself
    /// while they run (`PIActivityRefreshTests` covers that).
    private func viewModel(
        _ history: ActivityTestHistory,
        factory: ActivityViewModelFactoryProtocol = ActivityTestFactory(),
        assetId: String? = nil,
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> ActivityViewModel {
        ActivityViewModel(
            historyService: history,
            viewModelFactory: factory,
            wireframe: ActivityWireframe(),
            assetManager: PriceTestAssetManager(assets: []),
            eventCenter: ActivityTestEvents(),
            assetId: assetId,
            notificationCenter: notificationCenter,
            refreshDelay: { _ in 3_600 }
        )
    }

    private func rows(_ viewModel: ActivityViewModel) -> [String] {
        ActivityTestList.rows(viewModel)
    }

    private func notices(_ viewModel: ActivityViewModel) -> [String] {
        ActivityTestList.notices(viewModel)
    }

    private func retryRows(_ viewModel: ActivityViewModel) -> Int {
        ActivityTestList.retryRows(viewModel)
    }

    /// The old section-identity intersection missed a page when all of
    /// its rows merged into a day already on screen.
    @MainActor
    func testSameDayPagesArePublishedAndCountedOnce() async throws {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], day: "D"))
        history.set(2, page(["a3", "a4"], day: "D"))
        history.set(3, page(["b1"], day: "D-1", endReached: true))
        let viewModel = viewModel(history)
        let view = ActivityPagingTestView()
        viewModel.view = view

        viewModel.viewDidLoad()
        await wait("page 1 counted") { viewModel.pageNumber == 1 }
        let originalSection = try XCTUnwrap(viewModel.sections.first)
        let stopsAfterFirstPage = view.paginationStops
        viewModel.updateContent()
        XCTAssertTrue(view.isPaginating)
        await wait("page 2 published") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2", "a3", "a4"]
        }
        XCTAssertEqual(viewModel.pageNumber, 2)
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertTrue(viewModel.sections.first === originalSection)
        XCTAssertFalse(view.isPaginating)
        XCTAssertGreaterThan(view.paginationStops, stopsAfterFirstPage)

        viewModel.updateContent()
        await wait("page 3 counted") { viewModel.pageNumber == 3 }
        let expected = ["a1", "a2", "a3", "a4", "b1"]
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), expected)
        XCTAssertEqual(rows(viewModel), expected)
        XCTAssertEqual(history.requests, [1, 2, 3])
        XCTAssertFalse(view.isPaginating)
    }

    /// Two answers for the same page may be in flight, but only the
    /// first accepted answer may merge its rows or advance the list.
    @MainActor
    func testConcurrentSameDayPageAnswersDoNotDuplicateRows() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], day: "D"))
        history.set(2, page(["a3", "a4"], day: "D", endReached: true))
        let viewModel = viewModel(history)
        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }

        let gate = history.hold()
        viewModel.updateContent()
        viewModel.updateContent()
        await wait("page 2 requested") { history.requests.contains(2) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        gate.open()
        await wait("page 2 counted") { viewModel.pageNumber == 2 }
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(rows(viewModel), ["a1", "a2", "a3", "a4"])
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), rows(viewModel))
        XCTAssertEqual(viewModel.pageNumber, 2)
        viewModel.updateContent()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(history.requests.contains(3))
    }

    /// SubqueryHistoryOperation filters each remote page by asset. No
    /// matching rows in page 2 says nothing about matching rows in page 3.
    @MainActor
    func testEmptyFilteredMiddlePageAutomaticallyLoadsTheNextPage() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], day: "D"))
        history.set(2, page([], day: "D"))
        history.set(3, page(["a3", "a4"], day: "D", endReached: true))
        let viewModel = viewModel(history, assetId: priceTestXor)
        let view = ActivityPagingTestView()
        viewModel.view = view
        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }

        // One scroll must get past the empty page without another event
        // from a last visible row that has not changed.
        viewModel.updateContent()
        await wait("matching rows beyond the empty page") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2", "a3", "a4"]
        }
        XCTAssertEqual(viewModel.pageNumber, 3)
        XCTAssertEqual(history.requests, [1, 2, 3])
        XCTAssertEqual(history.requestedAssets, [priceTestXor, priceTestXor, priceTestXor])
        XCTAssertEqual(rows(viewModel), ["a1", "a2", "a3", "a4"])
        XCTAssertFalse(view.isPaginating)
    }

    @MainActor
    func testEmptyFilteredFirstPagesDoNotDeclareTheListEmpty() async {
        let history = ActivityTestHistory()
        history.set(1, page([], day: "D"))
        history.set(2, page([], day: "D"))
        history.set(3, page(["a1"], day: "D", endReached: true))
        let viewModel = viewModel(history, assetId: priceTestXor)
        var emptyLabels = 0
        viewModel.setupEmptyLabel = { emptyLabels += 1 }

        viewModel.viewDidLoad()
        await wait("the first matching page") { viewModel.pageNumber == 3 }
        XCTAssertEqual(history.requests, [1, 2, 3])
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1"])
        XCTAssertEqual(emptyLabels, 0)
    }

    @MainActor
    func testEmptyLastPageIsCountedAndEndsPaging() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], day: "D"))
        history.set(2, page([], day: "D", endReached: true))
        let viewModel = viewModel(history)
        let view = ActivityPagingTestView()
        viewModel.view = view
        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("empty final page counted") { viewModel.pageNumber == 2 }
        XCTAssertFalse(view.isPaginating)
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1", "a2"])
        for _ in 0..<3 { viewModel.updateContent() }
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(history.requests, [1, 2])
        XCTAssertFalse(view.isPaginating)
        XCTAssertEqual(retryRows(viewModel), 0)
    }

    @MainActor
    func testAnEmptyFirstAndLastPageEndsWithoutAnotherRequest() async {
        let history = ActivityTestHistory()
        history.set(1, page([], day: "D", endReached: true))
        let viewModel = viewModel(history, assetId: priceTestXor)
        var emptyLabels = 0
        viewModel.setupEmptyLabel = { emptyLabels += 1 }
        viewModel.viewDidLoad()
        await wait("the empty list counted") { viewModel.pageNumber == 1 }
        XCTAssertEqual(emptyLabels, 1)
        XCTAssertTrue(viewModel.snapshot.itemIdentifiers.isEmpty)
        viewModel.updateContent()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(history.requests, [1])
    }

    @MainActor
    func testEmptyFilteredPagesStopAtTheHistoryPageLimit() async {
        let history = ActivityTestHistory()
        let maximum = PIIndexerClient.maximumHistoryPages
        for number in 1...maximum {
            history.set(number, page([], day: "D"))
        }
        let viewModel = viewModel(history, assetId: priceTestXor)
        let view = ActivityPagingTestView()
        viewModel.view = view
        var emptyLabels = 0
        viewModel.setupEmptyLabel = { emptyLabels += 1 }

        viewModel.viewDidLoad()
        await wait("all permitted pages counted") { viewModel.pageNumber == maximum }
        XCTAssertEqual(history.requests, Array(1...maximum))
        XCTAssertEqual(emptyLabels, 1)
        XCTAssertEqual(retryRows(viewModel), 0)
        XCTAssertFalse(view.isPaginating)
        viewModel.updateContent()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(history.requests, Array(1...maximum))
    }

    /// Even an empty filtered page must come from the same history as
    /// the rows above it; it cannot silently bridge current and saved data.
    @MainActor
    func testAnEmptySavedPageCannotContinueACurrentList() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1"], day: "D"))
        history.set(2, page([], day: "D", cachedAt: Date().addingTimeInterval(-3_600)))
        history.set(3, page(["a2"], day: "D", endReached: true))
        let viewModel = viewModel(history, assetId: priceTestXor)
        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("the retry row") { self.retryRows(viewModel) == 1 }
        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(history.requests, [1, 2])
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1"])
        XCTAssertEqual(viewModel.shownPages, .current)

        history.set(2, page([], day: "D"))
        viewModel.updateContent()
        await wait("the consistent continuation") { viewModel.pageNumber == 3 }
        XCTAssertEqual(history.requests, [1, 2, 2, 3])
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1", "a2"])
        XCTAssertEqual(retryRows(viewModel), 0)
        XCTAssertEqual(viewModel.snapshot.itemIdentifiers.filter {
            if case .error = $0 { return true }
            return false
        }.count, 0)
    }

    /// The background refresh of a saved list also has to walk past an
    /// empty current first page instead of waiting for a row to be scrolled.
    @MainActor
    func testQuietRefreshContinuesPastAnEmptyCurrentFirstPage() async {
        let history = ActivityTestHistory()
        let savedAt = Date().addingTimeInterval(-3_600)
        history.set(1, page(["old1"], day: "D", cachedAt: savedAt))
        let center = NotificationCenter()
        let viewModel = viewModel(history, assetId: priceTestXor, notificationCenter: center)
        var emptyLabels = 0
        viewModel.setupEmptyLabel = { emptyLabels += 1 }
        viewModel.viewDidLoad()
        await wait("the saved list") { viewModel.pageNumber == 1 }
        XCTAssertTrue(viewModel.isBehind)
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [WalletUX.activityAsOfText(savedAt)])

        history.set(1, page([], day: "D"))
        history.set(2, page(["current1"], day: "D-1", endReached: true))
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        await wait("the current matching page after quiet refresh") {
            ActivityTestList.drawnRows(viewModel) == ["current1"]
        }
        XCTAssertEqual(viewModel.pageNumber, 2)
        XCTAssertEqual(history.requests, [1, 1, 2])
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertFalse(viewModel.isBehind)
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [])
        XCTAssertEqual(retryRows(viewModel), 0)
        XCTAssertEqual(emptyLabels, 0)
    }

    private func transferPage(
        _ hashes: [String],
        at date: Date,
        endReached: Bool = false
    ) -> HistoryPage {
        HistoryPage(
            transactions: hashes.enumerated().map { index, hash in
                TransferTransaction(
                    base: TransactionBase(
                        txHash: hash,
                        blockHash: "",
                        fee: Amount(value: 0),
                        status: .success,
                        timestamp: String(date.addingTimeInterval(-Double(index)).timeIntervalSince1970)
                    ),
                    amount: Amount(value: 1),
                    peer: hash,
                    transferType: .outcoming,
                    tokenId: priceTestXor
                )
            },
            endReached: endReached
        )
    }

    private func productionFactory() -> ActivityViewModelFactory {
        let assets = [
            AssetInfo(
                id: priceTestXor, symbol: "XOR", chainId: "", precision: 18,
                icon: nil, displayName: "SORA", visible: true
            ),
        ]
        return ActivityViewModelFactory(
            walletAssets: assets,
            assetManager: PriceTestAssetManager(assets: assets)
        )
    }

    /// The real factory groups by calendar day and retains currentDate
    /// between pages, including across pages with no matching transfers.
    @MainActor
    func testProductionFactoryMergesSameDayPagesAcrossAnEmptyPage() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 10, day: 11, hour: 12
        )))
        let previousDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: day))
        let factory = productionFactory()
        let history = ActivityTestHistory()
        history.set(1, transferPage(["a1", "a2"], at: day))
        history.set(2, transferPage(["a3", "a4"], at: day.addingTimeInterval(-60)))
        history.set(3, transferPage([], at: day))
        history.set(4, transferPage(["b1"], at: previousDay, endReached: true))
        let viewModel = viewModel(history, factory: factory, assetId: priceTestXor)

        viewModel.viewDidLoad()
        await wait("production page 1") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("production page 2") { viewModel.pageNumber == 2 }
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1", "a2", "a3", "a4"])
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(factory.currentDate, day.addingTimeInterval(-61))

        viewModel.updateContent()
        await wait("the previous calendar day") { viewModel.pageNumber == 4 }
        XCTAssertEqual(history.requests, [1, 2, 3, 4])
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1", "a2", "a3", "a4", "b1"])
        XCTAssertEqual(rows(viewModel), ActivityTestList.drawnRows(viewModel))
        XCTAssertEqual(viewModel.sections.map(\.date), [
            DateFormatter.activityDate.string(from: day),
            DateFormatter.activityDate.string(from: previousDay),
        ])
        XCTAssertEqual(viewModel.sections.map { $0.items.count }, [4, 1])
        XCTAssertEqual(factory.currentDate, previousDay)

        // Starting over must also clear the factory's date from page 4.
        history.set(1, transferPage(["n1"], at: day, endReached: true))
        viewModel.resetPagination()
        await wait("the replacement list") { ActivityTestList.drawnRows(viewModel) == ["n1"] }
        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(factory.currentDate, day)
    }

    private func descendants<View: UIView>(of view: UIView, as _: View.Type) -> [View] {
        view.subviews.flatMap { subview -> [View] in
            let own = (subview as? View).map { [$0] } ?? []
            return own + descendants(of: subview, as: View.self)
        }
    }

    @MainActor
    private func window(showing controller: UIViewController) throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.windowLevel = .alert
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.isHidden = false
        window.layoutIfNeeded()
        return window
    }

    @MainActor
    private func attach(_ window: UIWindow, as name: String) {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Self-sizing rows below the viewport initially have estimated
    /// heights. Let the table measure them and correct the scroll until
    /// the requested row really appears and its willDisplay callback runs.
    @MainActor
    private func scrollToRow(_ indexPath: IndexPath, in table: UITableView) async {
        for _ in 0..<10 {
            table.scrollToRow(at: indexPath, at: .bottom, animated: false)
            table.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 20_000_000)
            if table.indexPathsForVisibleRows?.contains(indexPath) == true { return }
        }
    }

    /// The real screen and factory on a simulator: scroll a 100-row day,
    /// then an asset-filtered list whose next matching row is beyond an
    /// empty remote page. Capture the long list and both list endings.
    @MainActor
    func testProductionScreenShowsLongAndAssetFilteredListsThroughTheirEnd() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 10, day: 11, hour: 12
        )))
        for filtered in [false, true] {
            let history = ActivityTestHistory()
            let first = (1...50).map { String(format: "Transfer %03d", $0) }
            let later = (51...(filtered ? 52 : 100)).map { String(format: "Transfer %03d", $0) }
            history.set(1, transferPage(first, at: day))
            if filtered {
                history.set(2, transferPage([], at: day))
                history.set(3, transferPage(later, at: day.addingTimeInterval(-60)))
                history.set(4, transferPage([], at: day, endReached: true))
            } else {
                history.set(2, transferPage(later, at: day.addingTimeInterval(-60)))
                history.set(3, transferPage([], at: day, endReached: true))
            }
            let viewModel = viewModel(
                history,
                factory: productionFactory(),
                assetId: filtered ? priceTestXor : nil
            )
            viewModel.title = filtered ? "XOR Activity" : "Activity"
            let controller = ActivityViewController(viewModel: viewModel)
            viewModel.view = controller
            let window = try window(showing: controller)
            defer { window.isHidden = true }
            let table = try XCTUnwrap(descendants(of: controller.view, as: UITableView.self).first)
            func screenState() -> String {
                let counts = (0..<table.numberOfSections).map { table.numberOfRows(inSection: $0) }
                return "filtered=\(filtered), requested=\(history.requests), page=\(viewModel.pageNumber), "
                    + "tableRows=\(counts), snapshotRows=\(ActivityTestList.drawnRows(viewModel).count), "
                    + "visible=\(table.indexPathsForVisibleRows ?? []), offset=\(table.contentOffset), "
                    + "size=\(table.contentSize), bounds=\(table.bounds), inset=\(table.adjustedContentInset)"
            }
            await wait("the first 50 rows on screen") {
                table.numberOfSections == 1 && table.numberOfRows(inSection: 0) == 50
            }
            guard table.numberOfSections == 1, table.numberOfRows(inSection: 0) == 50 else {
                attach(window, as: "activity-paging-first-page-failure")
                return XCTFail("The first page was not drawn: \(screenState())")
            }
            window.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 150_000_000)
            if !filtered { attach(window, as: "activity-paging-long-list") }

            await scrollToRow(IndexPath(row: 49, section: 0), in: table)
            await wait("the continuation on screen") {
                table.numberOfSections == 1
                    && table.numberOfRows(inSection: 0) == first.count + later.count
            }
            guard table.numberOfSections == 1,
                  table.numberOfRows(inSection: 0) == first.count + later.count else {
                attach(window, as: "activity-paging-continuation-failure")
                return XCTFail("The same-day continuation was not drawn: \(screenState())")
            }
            XCTAssertEqual(ActivityTestList.drawnRows(viewModel), first + later)
            XCTAssertEqual(rows(viewModel), first + later)
            await scrollToRow(IndexPath(row: first.count + later.count - 1, section: 0), in: table)
            let lastPage = filtered ? 4 : 3
            await wait("the final empty page and no spinner") {
                viewModel.pageNumber == lastPage && table.tableFooterView == nil
            }
            try await Task.sleep(nanoseconds: 150_000_000)
            XCTAssertTrue(history.requests.contains(lastPage))
            XCTAssertFalse(history.requests.contains { $0 > lastPage })
            XCTAssertEqual(Set(history.requests), Set(1...lastPage))
            XCTAssertEqual(retryRows(viewModel), 0)
            XCTAssertEqual(history.requestedAssets, history.requests.map { _ in filtered ? priceTestXor : nil })
            attach(window, as: filtered ? "activity-paging-asset-filtered-end" : "activity-paging-long-list-end")
            let requestsAtEnd = history.requests
            viewModel.updateContent()
            try await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertEqual(history.requests, requestsAtEnd)
            XCTAssertNil(table.tableFooterView)
        }
    }

    func testTheRuleForPuttingAPageUnderTheList() {
        let earlier = Date(timeIntervalSince1970: 1_791_700_000)
        let later = earlier.addingTimeInterval(60)
        XCTAssertTrue(ActivityViewModel.continues(.none, pageCachedAt: nil))
        XCTAssertTrue(ActivityViewModel.continues(.none, pageCachedAt: earlier))
        XCTAssertTrue(ActivityViewModel.continues(.current, pageCachedAt: nil))
        XCTAssertFalse(ActivityViewModel.continues(.current, pageCachedAt: earlier))
        XCTAssertFalse(ActivityViewModel.continues(.saved(earlier), pageCachedAt: nil))
        XCTAssertTrue(ActivityViewModel.continues(.saved(earlier), pageCachedAt: earlier))
        XCTAssertTrue(ActivityViewModel.continues(.saved(earlier), pageCachedAt: later))
        XCTAssertFalse(ActivityViewModel.continues(.saved(later), pageCachedAt: earlier))
    }

    /// Page 1 loads from the indexer. Then the indexer cannot be read, and
    /// the page 2 that comes back is the one saved hours ago, when the
    /// account had fewer transactions: its rows start further up the list.
    /// It is not put under the current page; a row offers to load the list
    /// again. When the indexer answers, the current page 2 goes in.
    func testASavedPageIsNotPutUnderCurrentPages() async throws {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], day: "1"))
        history.set(
            2,
            page(["a2", "b1"], day: "2", cachedAt: Date().addingTimeInterval(-7_200))
        )
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("page 1") { self.rows(viewModel) == ["a1", "a2"] }
        await wait("page 1 counted") { viewModel.pageNumber == 1 }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertEqual(notices(viewModel), [])

        viewModel.updateContent()
        await wait("the saved page was offered") { history.requests == [1, 2] }
        await wait("the retry row") { self.retryRows(viewModel) == 1 }
        XCTAssertEqual(rows(viewModel), ["a1", "a2"])
        XCTAssertEqual(viewModel.pageNumber, 1)

        // Scrolling to the end again asks again and adds no second row.
        viewModel.updateContent()
        await wait("asked again") { history.requests == [1, 2, 2] }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(retryRows(viewModel), 1)
        XCTAssertEqual(rows(viewModel), ["a1", "a2"])

        // The indexer answers again.
        history.set(2, page(["b1", "b2"], day: "2"))
        viewModel.updateContent()
        await wait("the current page 2") {
            self.rows(viewModel) == ["a1", "a2", "b1", "b2"]
        }
        XCTAssertEqual(retryRows(viewModel), 0)
        XCTAssertEqual(viewModel.shownPages, .current)
    }

    /// The indexer cannot be read when Activity opens: the list is the one
    /// saved earlier, and says when it is from. An older saved page, or a
    /// current one, is not put under it. Loading again from the start
    /// gives one consistent list.
    func testTheSavedListSaysWhenItIsFromAndStaysInOnePiece() async throws {
        let savedAt = Date().addingTimeInterval(-3_600)
        let history = ActivityTestHistory()
        history.set(1, page(["a1"], day: "1", cachedAt: savedAt))
        history.set(
            2,
            page(["x1"], day: "2", cachedAt: savedAt.addingTimeInterval(-600))
        )
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("the saved page 1") { self.rows(viewModel) == ["a1"] }
        await wait("page 1 counted") { viewModel.pageNumber == 1 }
        XCTAssertEqual(viewModel.shownPages, .saved(savedAt))
        // The line that says when the list is from has a Refresh button.
        XCTAssertEqual(
            ActivityTestList.refreshRows(viewModel),
            [WalletUX.activityAsOfText(savedAt)]
        )
        XCTAssertEqual(notices(viewModel), [])

        // A page saved before the one above it.
        viewModel.updateContent()
        await wait("the retry row") { self.retryRows(viewModel) == 1 }
        XCTAssertEqual(rows(viewModel), ["a1"])

        // A page saved after it continues the saved list.
        let laterSave = savedAt.addingTimeInterval(30)
        history.set(2, page(["b1"], day: "2", cachedAt: laterSave))
        viewModel.updateContent()
        await wait("the saved page 2") { self.rows(viewModel) == ["a1", "b1"] }
        await wait("page 2 counted") { viewModel.pageNumber == 2 }
        XCTAssertEqual(retryRows(viewModel), 0)
        XCTAssertEqual(viewModel.shownPages, .saved(laterSave))

        // The indexer answers again: its page 3 is not put under the
        // saved list.
        history.set(3, page(["c1"], day: "3"))
        viewModel.updateContent()
        await wait("the retry row") { self.retryRows(viewModel) == 1 }
        XCTAssertEqual(rows(viewModel), ["a1", "b1"])

        // "Refresh" loads the list again from its start, now current.
        history.set(1, page(["n1", "a1"], day: "1"))
        viewModel.resetPagination()
        await wait("the current list") { self.rows(viewModel) == ["n1", "a1"] }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertEqual(notices(viewModel), [])
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [])
        XCTAssertEqual(retryRows(viewModel), 0)
    }

    func testTheActivityAsOfTextInEnglishAndJapanese() {
        let zone = try! XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = Date(timeIntervalSince1970: 1_791_700_000)
        let earlier = now.addingTimeInterval(-3_600)

        let english = WalletUX.activityAsOfText(
            earlier,
            now: now,
            language: "en",
            calendar: calendar,
            timeZone: zone
        )
        let japanese = WalletUX.activityAsOfText(
            earlier,
            now: now,
            language: "ja",
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertTrue(english.hasPrefix("Activity as of "), english)
        XCTAssertTrue(
            english.hasSuffix(
                ". Newer transactions will appear when the list can be updated."
            ),
            english
        )
        XCTAssertTrue(japanese.contains("時点のアクティビティです"), japanese)
        XCTAssertFalse(japanese.contains("%@"))
        XCTAssertNotEqual(english, japanese)
    }
}

// MARK: - Review round 5: a list that is behind becomes current again

/// The saved Activity list said "Newer transactions will appear when the
/// list can be updated" and then nothing ever updated it: no button, no
/// timer, nothing when the app or the tab came back. Only a transaction
/// made in the wallet, or killing the app, loaded it again.
final class PIActivityRefreshTests: XCTestCase {
    private let center = NotificationCenter()

    @MainActor
    private func wait(
        _ what: String,
        until condition: () -> Bool
    ) async {
        for _ in 0 ..< 1_000 where !condition() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    /// Time for something that must not happen to happen.
    @MainActor
    private func settle() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func page(
        _ hashes: [String],
        day: String = "1",
        cachedAt: Date? = nil,
        endReached: Bool = false
    ) -> HistoryPage {
        HistoryPage(
            transactions: hashes.map { ActivityTestTransaction($0, day: day) },
            endReached: endReached,
            cachedAt: cachedAt
        )
    }

    /// - Parameter wait: The wait before the list asks again by itself.
    ///   An hour, unless the test is about that.
    private func viewModel(
        _ history: ActivityTestHistory,
        wait: @escaping (Int) -> TimeInterval = { _ in 3_600 },
        uptime: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) -> ActivityViewModel {
        ActivityViewModel(
            historyService: history,
            viewModelFactory: ActivityTestFactory(),
            wireframe: ActivityWireframe(),
            assetManager: PriceTestAssetManager(assets: []),
            eventCenter: ActivityTestEvents(),
            notificationCenter: center,
            refreshDelay: wait,
            uptime: uptime
        )
    }

    private let savedAt = Date().addingTimeInterval(-3_600)

    private var asOf: String { WalletUX.activityAsOfText(savedAt) }

    // MARK: The schedule

    func testTheWaitsGrowAndStopAtFiveMinutes() {
        XCTAssertEqual(
            [0, 1, 2, 3, 4, 5, 6, 40].map(
                ActivityViewModel.refreshDelay(afterFailures:)
            ),
            [15, 30, 60, 120, 240, 300, 300, 300]
        )
        XCTAssertEqual(ActivityViewModel.refreshDelay(afterFailures: -3), 15)
        XCTAssertEqual(ActivityViewModel.minimumRefreshSpacing, 15)
    }

    // MARK: By itself

    /// The scenario of the finding: no signal when Activity opens, the
    /// saved list is shown, the network returns. Nothing is tapped and no
    /// transaction is made.
    @MainActor
    func testTheSavedListBecomesCurrentByItself() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1"], cachedAt: savedAt))
        var waits: [Int] = []
        let viewModel = viewModel(history, wait: { failures in
            waits.append(failures)
            return 0.02
        })

        viewModel.viewDidLoad()
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1"]
        }
        XCTAssertEqual(viewModel.shownPages, .saved(savedAt))
        XCTAssertTrue(viewModel.isBehind)
        // The line that says when the list is from comes with a button.
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [asOf])

        // The indexer still cannot be read: page 1 is asked for again and
        // again, each time after a longer wait, and the list stays.
        await wait("asked again by itself") { history.requests.count >= 5 }
        XCTAssertTrue(history.requests.allSatisfy { $0 == 1 })
        XCTAssertEqual(Array(waits.prefix(4)), [0, 1, 2, 3])
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1"])
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [asOf])
        XCTAssertEqual(viewModel.shownPages, .saved(savedAt))

        // The indexer answers again.
        history.set(1, page(["n1", "a1"]))
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1"]
        }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertFalse(viewModel.isBehind)
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [])
        XCTAssertEqual(viewModel.pageNumber, 1)

        // A current list asks for nothing more.
        let asked = history.requests.count
        await settle()
        XCTAssertEqual(history.requests.count, asked)
    }

    /// Nothing could be shown when Activity opened: "Could not load your
    /// activity" with its Refresh button. That state loads by itself too,
    /// and takes the saved copy when that is all there is.
    @MainActor
    func testAListThatCouldNotBeLoadedLoadsByItself() async {
        let history = ActivityTestHistory()
        var errorsShown = 0
        var errorsHidden = 0
        let viewModel = viewModel(history, wait: { _ in 0.02 })
        viewModel.setupErrorContent = { errorsShown += 1 }
        viewModel.hideErrorContent = { errorsHidden += 1 }

        viewModel.viewDidLoad()
        await wait("the error") { errorsShown == 1 }
        XCTAssertTrue(viewModel.isBehind)
        XCTAssertEqual(viewModel.shownPages, .none)
        XCTAssertEqual(viewModel.snapshot.numberOfItems, 0)
        await wait("asked again by itself") { history.requests.count >= 3 }
        XCTAssertEqual(errorsShown, 1)

        // The saved copy can be read: better than the error.
        history.set(1, page(["a1"], cachedAt: savedAt))
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1"]
        }
        XCTAssertEqual(errorsHidden, 1)
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [asOf])
        XCTAssertTrue(viewModel.isBehind)

        // And then the indexer.
        history.set(1, page(["n1", "a1"]))
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1"]
        }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertFalse(viewModel.isBehind)
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [])
    }

    /// The saved list of an account whose incoming transfers the indexer
    /// could not list: the Refresh row is the first row, the notice comes
    /// under it as part of the same card.
    @MainActor
    func testTheSavedListKeepsTheNoticeAboutIncomingTransfers() async throws {
        let history = ActivityTestHistory()
        history.set(
            1,
            HistoryPage(
                transactions: [ActivityTestTransaction("a1", day: "1")],
                endReached: true,
                mayOmitIncomingTransfers: true,
                cachedAt: savedAt
            )
        )
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1"]
        }
        let top = try XCTUnwrap(viewModel.sections.first).items
        XCTAssertEqual(top.count, 2)
        guard
            case let .error(refresh) = top[0],
            case let .notice(notice) = top[1]
        else {
            return XCTFail("\(top)")
        }
        XCTAssertEqual(refresh.title, asOf)
        XCTAssertTrue(refresh.roundsTop)
        XCTAssertEqual(notice.text, ActivityViewModel.incompleteHistoryNotice)
        XCTAssertFalse(notice.roundsTop)

        // Without a saved copy above it, the notice is the top of the card.
        history.set(
            1,
            HistoryPage(
                transactions: [ActivityTestTransaction("a1", day: "1")],
                endReached: true,
                mayOmitIncomingTransfers: true
            )
        )
        viewModel.resetPagination()
        await wait("the current list") { viewModel.shownPages == .current }
        let current = try XCTUnwrap(viewModel.sections.first).items
        guard current.count == 1, case let .notice(only) = current[0] else {
            return XCTFail("\(current)")
        }
        XCTAssertTrue(only.roundsTop)
    }

    // MARK: When the app or the screen comes back

    @MainActor
    func testComingToTheForegroundLoadsTheListAgain() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1"], cachedAt: savedAt))
        var waits: [Int] = []
        let viewModel = viewModel(history, wait: { failures in
            waits.append(failures)
            return 3_600
        })

        viewModel.viewDidLoad()
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1"]
        }
        await settle()
        XCTAssertEqual(history.requests, [1])

        // Still no indexer when the app comes back: asked once, the list
        // stays, and the waits start from the short end again.
        center.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        await wait("asked when the app came back") {
            history.requests == [1, 1]
        }
        await wait("the next wait") { waits == [0, 1] }
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1"])
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [asOf])

        // The indexer answers the next time.
        history.set(1, page(["n1", "a1"]))
        center.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1"]
        }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertEqual(history.requests, [1, 1, 1])

        // A current list is left alone.
        center.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        viewModel.viewWillAppear()
        await settle()
        XCTAssertEqual(history.requests, [1, 1, 1])
    }

    /// Leaving the tab and coming back asks again, but not when page 1 was
    /// answered a moment ago: switching tabs quickly costs nothing.
    @MainActor
    func testComingBackToTheScreenLoadsTheListAgain() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1"], cachedAt: savedAt))
        var now: TimeInterval = 1_000
        let viewModel = viewModel(history, uptime: { now })

        viewModel.viewDidLoad()
        // The first appearance, while page 1 is still on its way.
        viewModel.viewWillAppear()
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1"]
        }
        XCTAssertEqual(history.requests, [1])

        now += 5
        viewModel.viewWillAppear()
        await settle()
        XCTAssertEqual(history.requests, [1])

        now += 11
        viewModel.viewWillAppear()
        await wait("asked when the screen came back") {
            history.requests == [1, 1]
        }
        await settle()
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1"])

        // At once again: not asked.
        viewModel.viewWillAppear()
        await settle()
        XCTAssertEqual(history.requests, [1, 1])

        history.set(1, page(["n1", "a1"]))
        now += 16
        viewModel.viewWillAppear()
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1"]
        }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertEqual(history.requests, [1, 1, 1])
    }

    // MARK: Loads that cross

    /// The list is asked for again by itself and, before the answer, the
    /// user taps Refresh. One list is shown, no row twice, and when it is
    /// the saved copy again the list keeps asking.
    @MainActor
    func testRefreshByTheUserWhileTheListAsksByItself() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], cachedAt: savedAt))
        let viewModel = viewModel(history, wait: { _ in 0.02 })

        viewModel.viewDidLoad()
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2"]
        }
        var gate = history.hold()
        let before = history.requests.count
        await wait("asked by itself") {
            history.requests.count == before + 1
        }
        viewModel.resetPagination()
        await wait("asked by the user") {
            history.requests.count == before + 2
        }
        gate.open()
        await wait("the saved list again") {
            ActivityTestList.rows(viewModel) == ["a1", "a2"]
                && viewModel.pageNumber == 1
        }
        await settle()
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1", "a2"])
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [asOf])
        XCTAssertTrue(viewModel.isBehind)
        // It still asks by itself.
        let afterRefresh = history.requests.count
        await wait("keeps asking") {
            history.requests.count >= afterRefresh + 2
        }

        // The same crossing, and this time the indexer answers both.
        gate = history.hold()
        let held = history.requests.count
        await wait("asked by itself") {
            history.requests.count == held + 1
        }
        viewModel.resetPagination()
        await wait("asked by the user") {
            history.requests.count == held + 2
        }
        history.set(1, page(["n1", "a1", "a2"]))
        gate.open()
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1", "a2"]
        }
        await settle()
        XCTAssertEqual(
            ActivityTestList.rows(viewModel),
            ["n1", "a1", "a2"]
        )
        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertFalse(viewModel.isBehind)
        let asked = history.requests.count
        await settle()
        XCTAssertEqual(history.requests.count, asked)
    }

    /// Two transactions arrive together and each loads the list again:
    /// the second answer used to be put under the first as "page 2".
    @MainActor
    func testTwoLoadsThatCrossShowOneList() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"]))
        history.set(2, page(["b1"], day: "2"))
        let viewModel = viewModel(history)

        var gate = history.hold()
        viewModel.resetPagination()
        viewModel.resetPagination()
        await wait("both asked") { history.requests == [1, 1] }
        gate.open()
        await wait("the list") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2"]
        }
        await settle()
        XCTAssertEqual(ActivityTestList.rows(viewModel), ["a1", "a2"])
        XCTAssertEqual(viewModel.pageNumber, 1)

        // The end of the list is shown twice before page 2 arrives.
        gate = history.hold()
        viewModel.updateContent()
        viewModel.updateContent()
        await wait("both asked") { history.requests == [1, 1, 2, 2] }
        gate.open()
        await wait("page 2") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2", "b1"]
        }
        await settle()
        XCTAssertEqual(ActivityTestList.rows(viewModel), ["a1", "a2", "b1"])
        XCTAssertEqual(viewModel.pageNumber, 2)
    }

    // MARK: The end of the list

    /// Page 1 is current, the network goes, and there is no saved copy of
    /// page 2: the spinner at the end of the list used to turn for ever.
    @MainActor
    func testAFurtherPageThatCannotBeReadOffersRefresh() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"]))
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("the retry row") {
            ActivityTestList.retryRows(viewModel) == 1
        }
        XCTAssertEqual(ActivityTestList.drawnRows(viewModel), ["a1", "a2"])
        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertFalse(viewModel.isBehind)

        // Scrolling to the end again asks again; one row.
        viewModel.updateContent()
        await wait("asked again") { history.requests == [1, 2, 2] }
        await settle()
        XCTAssertEqual(ActivityTestList.retryRows(viewModel), 1)

        history.set(2, page(["b1"], day: "2"))
        viewModel.updateContent()
        await wait("page 2") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2", "b1"]
        }
        XCTAssertEqual(ActivityTestList.retryRows(viewModel), 0)
    }

    /// A list that ended is not asked for more, so a short saved list has
    /// its one Refresh row and no second one at its end.
    @MainActor
    func testNothingIsAskedPastTheEndOfTheList() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1"], cachedAt: savedAt, endReached: true))
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("the saved list") {
            ActivityTestList.drawnRows(viewModel) == ["a1"]
        }
        await wait("page 1 counted") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await settle()
        XCTAssertEqual(history.requests, [1])
        XCTAssertEqual(ActivityTestList.retryRows(viewModel), 0)
        XCTAssertEqual(ActivityTestList.refreshRows(viewModel), [asOf])

        // A longer list is asked for its next page, and then no more.
        history.set(1, page(["n1", "a1"]))
        history.set(2, page(["b1"], day: "2", endReached: true))
        viewModel.resetPagination()
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1"]
        }
        await wait("page 1 counted") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("page 2") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1", "b1"]
        }
        viewModel.updateContent()
        await settle()
        XCTAssertEqual(history.requests, [1, 1, 2])
    }

    /// More operations in one day than fit on a page: every row of page 2
    /// belongs to the day that is on screen already. Such a page was kept
    /// in memory, never drawn and never counted; the spinner stayed and
    /// each scroll to the end read the same page and kept it once more.
    @MainActor
    func testAPageOfADayAlreadyOnScreenIsDrawnAndCounted() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], day: "1"))
        history.set(2, page(["a3", "a4"], day: "1"))
        history.set(3, page(["b1"], day: "2", endReached: true))
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("page 2 drawn") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2", "a3", "a4"]
        }
        XCTAssertEqual(viewModel.pageNumber, 2)
        XCTAssertEqual(viewModel.sections.count, 1)

        viewModel.updateContent()
        await wait("page 3 drawn") {
            ActivityTestList.drawnRows(viewModel)
                == ["a1", "a2", "a3", "a4", "b1"]
        }
        XCTAssertEqual(viewModel.pageNumber, 3)
        XCTAssertEqual(history.requests, [1, 2, 3])
        XCTAssertEqual(
            ActivityTestList.rows(viewModel),
            ["a1", "a2", "a3", "a4", "b1"]
        )
    }

    /// The history has more pages than the client reads: the list ends
    /// there, without a row that offers what cannot be had.
    @MainActor
    func testTheLastPageTheClientReadsEndsTheList() async {
        let history = ActivityTestHistory()
        history.set(1, page(["a1"]))
        history.fail(2, with: PIIndexerError.paginationLimit)
        let viewModel = viewModel(history)

        viewModel.viewDidLoad()
        await wait("page 1") { viewModel.pageNumber == 1 }
        viewModel.updateContent()
        await wait("asked") { history.requests == [1, 2] }
        await settle()
        XCTAssertEqual(ActivityTestList.retryRows(viewModel), 0)
        viewModel.updateContent()
        await settle()
        XCTAssertEqual(history.requests, [1, 2])
    }

    // MARK: On screen

    private func descendants<View: UIView>(
        of view: UIView,
        as _: View.Type
    ) -> [View] {
        view.subviews.flatMap { subview -> [View] in
            let own = (subview as? View).map { [$0] } ?? []
            return own + descendants(of: subview, as: View.self)
        }
    }

    private func texts(in view: UIView) -> [String] {
        descendants(of: view, as: UILabel.self)
            .filter { !$0.isHidden }
            .compactMap { $0.attributedText?.string ?? $0.text }
            .filter { !$0.isEmpty }
    }

    private func refreshCells(
        in controller: UIViewController
    ) -> [ActivityErrorCell] {
        descendants(of: controller.view, as: ActivityErrorCell.self)
            .filter { $0.window != nil && !$0.isHidden }
    }

    /// A finger down on the button and up again. The app's buttons act
    /// when the finger goes down.
    @MainActor
    private func tap(_ button: UIControl) {
        button.sendActions(for: .touchDown)
        button.sendActions(for: .touchUpInside)
    }

    /// A window of the running app with the screen in it, so that the
    /// table lays out and draws its rows as it does for a user.
    @MainActor
    private func window(
        showing controller: UIViewController
    ) throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.windowLevel = .alert
        window.rootViewController = UINavigationController(
            rootViewController: controller
        )
        window.isHidden = false
        window.layoutIfNeeded()
        return window
    }

    @MainActor
    private func attach(_ window: UIWindow, as name: String) {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The production screen on the production view model: the saved list
    /// has a Refresh button under the line that says when it is from, the
    /// button loads the list again, and the row goes when the list is
    /// current.
    @MainActor
    func testTheSavedListOnScreenHasARefreshButton() async throws {
        let history = ActivityTestHistory()
        history.set(
            1,
            page(["a1", "a2", "a3"], cachedAt: savedAt, endReached: true)
        )
        let viewModel = viewModel(history)
        viewModel.title = "Activity"
        let controller = ActivityViewController(viewModel: viewModel)
        viewModel.view = controller

        let window = try window(showing: controller)
        defer { window.isHidden = true }

        await wait("the Refresh row on screen") {
            self.refreshCells(in: controller).count == 1
        }
        await settle()
        let cell = try XCTUnwrap(refreshCells(in: controller).first)
        let refresh = R.string.localizable.commonRefresh(
            preferredLanguages: .currentLocale
        )
        XCTAssertEqual(texts(in: cell), [asOf, refresh])
        let table = try XCTUnwrap(
            descendants(of: controller.view, as: UITableView.self).first
        )
        XCTAssertEqual(table.indexPath(for: cell), IndexPath(row: 0, section: 0))
        // A list that ended has no spinner at its end and asked for no
        // page 2.
        XCTAssertNil(table.tableFooterView)
        XCTAssertEqual(history.requests, [1])
        attach(window, as: "activity-saved-list")

        // Still no indexer: the button asks, and the same list is shown.
        var button = try XCTUnwrap(
            descendants(of: cell, as: SoramitsuButton.self).first
        )
        tap(button)
        await wait("asked by the button") { history.requests == [1, 1] }
        await wait("the saved list again") {
            self.refreshCells(in: controller).count == 1
                && viewModel.pageNumber == 1
        }
        XCTAssertEqual(
            ActivityTestList.drawnRows(viewModel),
            ["a1", "a2", "a3"]
        )

        // The indexer answers: the list is current and the row is gone.
        history.set(1, page(["n1", "a1", "a2", "a3"], endReached: true))
        await settle()
        let again = try XCTUnwrap(refreshCells(in: controller).first)
        button = try XCTUnwrap(
            descendants(of: again, as: SoramitsuButton.self).first
        )
        tap(button)
        await wait("the current list") {
            ActivityTestList.drawnRows(viewModel) == ["n1", "a1", "a2", "a3"]
        }
        await wait("the Refresh row is gone") {
            self.refreshCells(in: controller).isEmpty
        }
        XCTAssertEqual(viewModel.shownPages, .current)
        XCTAssertEqual(history.requests, [1, 1, 1])
        attach(window, as: "activity-current-list")
    }

    /// On screen, a further page that cannot be read ends the list with
    /// the "Some data is not up to date" row and its Refresh button, and
    /// no spinner is left turning under it.
    @MainActor
    func testTheEndOfTheListOnScreenWhenAFurtherPageCannotBeRead() async throws {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2", "a3"]))
        let viewModel = viewModel(history)
        viewModel.title = "Activity"
        let controller = ActivityViewController(viewModel: viewModel)
        viewModel.view = controller
        let window = try window(showing: controller)
        defer { window.isHidden = true }

        // Showing the last row asks for page 2 by itself.
        await wait("the retry row on screen") {
            self.refreshCells(in: controller).count == 1
        }
        await settle()
        let cell = try XCTUnwrap(refreshCells(in: controller).first)
        XCTAssertEqual(
            texts(in: cell),
            [
                R.string.localizable.activityDataNotUpToDateTitle(
                    preferredLanguages: .currentLocale
                ),
                R.string.localizable.commonRefresh(
                    preferredLanguages: .currentLocale
                ),
            ]
        )
        let table = try XCTUnwrap(
            descendants(of: controller.view, as: UITableView.self).first
        )
        XCTAssertNil(table.tableFooterView)
        XCTAssertEqual(ActivityTestList.retryRows(viewModel), 1)
        XCTAssertEqual(
            ActivityTestList.drawnRows(viewModel),
            ["a1", "a2", "a3"]
        )
        // Page 2 was asked for when the last row was shown and once more
        // when the retry row was; then the screen is at rest.
        let asked = history.requests
        XCTAssertEqual(asked.first, 1)
        XCTAssertLessThanOrEqual(asked.count, 3)
        await settle()
        XCTAssertEqual(history.requests, asked)
        attach(window, as: "activity-end-of-list-retry")

        // The button loads the list again from its start.
        history.set(2, page(["b1"], day: "2", endReached: true))
        tap(try XCTUnwrap(descendants(of: cell, as: SoramitsuButton.self).first))
        await wait("both pages") {
            ActivityTestList.drawnRows(viewModel) == ["a1", "a2", "a3", "b1"]
        }
        await wait("the retry row is gone") {
            self.refreshCells(in: controller).isEmpty
        }
        await wait("no spinner at the end") { table.tableFooterView == nil }
        XCTAssertEqual(history.requests.suffix(2), [1, 2])
    }

    /// Refresh on a saved list when not even the saved copy can be read
    /// any more: the rows go, the "Could not load your activity" text with
    /// its Refresh button stands alone, and the spinner stops.
    @MainActor
    func testRefreshThatFailsLeavesNoRowsUnderTheError() async throws {
        let history = ActivityTestHistory()
        history.set(1, page(["a1", "a2"], cachedAt: savedAt, endReached: true))
        let viewModel = viewModel(history)
        let controller = ActivityViewController(viewModel: viewModel)
        viewModel.view = controller

        let window = try window(showing: controller)
        defer { window.isHidden = true }

        await wait("the Refresh row on screen") {
            self.refreshCells(in: controller).count == 1
        }
        history.set(1, nil)
        let cell = try XCTUnwrap(refreshCells(in: controller).first)
        let button = try XCTUnwrap(
            descendants(of: cell, as: SoramitsuButton.self).first
        )
        tap(button)

        let table = try XCTUnwrap(
            descendants(of: controller.view, as: UITableView.self).first
        )
        await wait("no rows") { table.numberOfSections == 0 }
        let errorView = try XCTUnwrap(
            descendants(of: controller.view, as: ErrorView.self)
                .first { $0.superview === controller.view }
        )
        await wait("the error") { !errorView.isHidden }
        let spinner = try XCTUnwrap(
            descendants(of: table, as: UIActivityIndicatorView.self).first
        )
        await wait("the spinner stopped") { !spinner.isAnimating }
        XCTAssertTrue(viewModel.isBehind)
        XCTAssertEqual(
            texts(in: errorView),
            [
                R.string.localizable.activityErrorTitle(
                    preferredLanguages: .currentLocale
                ),
                R.string.localizable.commonRefresh(
                    preferredLanguages: .currentLocale
                ),
            ]
        )
        attach(window, as: "activity-could-not-load")
    }
}
