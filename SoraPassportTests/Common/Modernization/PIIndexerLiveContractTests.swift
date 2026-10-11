// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import SoraKeystore
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
        var headers = ["Content-Type": "application/json"]
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
    var assetRows: [String]
    /// The `totalCount` to report for a page request, by its 1-based number.
    var totalCountForPageRead: ((Int) -> Int)?
    var failsPagesWithStatus: Int?
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
            height = heightForHealthRead?(healthReads, height) ?? height
            return .init(
                body: Self.health(
                    indexed: height,
                    finalized: height + 1,
                    indexedAt: Int(serverNow.timeIntervalSince1970) - indexAge,
                    serviceId: serviceId
                ),
                dateHeader: dateHeader
            )
        case "MobileAssets":
            pageReads += 1
            if let status = failsPagesWithStatus {
                return .init(status: status, body: "{}", dateHeader: dateHeader)
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
        serviceId: String = "pi.soramitsu.io"
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
        "workerLifecycle":"running","workerStartupComplete":true,\
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
    func testServerDateWithinTheTrustedSkewReplacesTheDeviceClock() {
        let device = Date(timeIntervalSince1970: 1_791_680_000)
        for skew in [-7_200, -31, 0, 45, 3_600, 26 * 3_600] {
            let server = device.addingTimeInterval(TimeInterval(skew))
            let clock = PIIndexerClient.responseClock(
                dateHeader: PIStubIndexerProtocol.httpDate(server),
                deviceNow: device
            )
            XCTAssertEqual(clock.nowEpochSeconds, 1_791_680_000 + skew)
            XCTAssertEqual(clock.deviceSkewSeconds, skew)
        }
    }

    func testMissingMalformedOrDistantServerDateFallsBackToTheDeviceClock() {
        let device = Date(timeIntervalSince1970: 1_791_680_000)
        let untrusted: [String?] = [
            nil,
            "",
            "yesterday",
            "2026-10-11T01:00:01Z",
            "Sun, 11 Oct 2026 01:00:01 JST",
            // More than 26 hours away from the device clock.
            PIStubIndexerProtocol.httpDate(
                device.addingTimeInterval(27 * 3_600)
            ),
            PIStubIndexerProtocol.httpDate(
                device.addingTimeInterval(-3 * 24 * 3_600)
            ),
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
        // An outage is not retried in a loop.
        XCTAssertEqual(pageReads(), 1)
        XCTAssertTrue(pauses.isEmpty)
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

    /// A `Date` header days away from the device clock is not trusted, so a
    /// replayed old response cannot pass as fresh.
    func testAServerDateFarFromTheDeviceClockIsNotTrusted() async throws {
        let indexer = try indexer()
        indexer.clockOffset = -3 * 24 * 3_600

        do {
            _ = try await client().qualifiedAllAssets(
                pageSize: 3,
                maximumPages: 5
            )
            XCTFail("Timestamps three days old were accepted")
        } catch {
            guard case PIIndexerError.staleCheckpoint = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
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

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
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
            lock.lock()
            calls += 1
            let result = self.result
            let delay = delayNanoseconds
            lock.unlock()
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            return try result.get()
        }
    }

    private func store(
        _ source: Source,
        freshFor: TimeInterval = 600,
        lastGoodFor: TimeInterval = 24 * 3_600
    ) -> PICatalogStore<String> {
        PICatalogStore(
            freshFor: freshFor,
            lastGoodFor: lastGoodFor,
            retryDelays: [15, 30, 60],
            uptime: { source.now },
            load: { try await source.load() }
        )
    }

    private func cached(_ values: [String]) -> PIQualifiedRead<[String]> {
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
            )
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
        XCTAssertEqual(source.callCount, 2)
        // No new request while backing off; the last good catalog is shown.
        let again = try await store.values()
        XCTAssertEqual(again, ["a"])
        XCTAssertEqual(source.callCount, 2)

        source.advance(16)
        source.result = .success(
            PIQualifiedRead(value: ["b"], qualification: nil)
        )
        let recovered = try await store.values()
        XCTAssertEqual(recovered, ["b"])
        XCTAssertEqual(source.callCount, 3)
        // A success clears the backoff.
        source.advance(601)
        source.result = .failure(PIIndexerError.staleCheckpoint)
        _ = try await store.values()
        source.advance(16)
        _ = try await store.values()
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
        let live = try await store.values()
        XCTAssertEqual(live, ["live"])
        XCTAssertEqual(source.callCount, 2)
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
    /// never stand in for a failed live read.
    private func freshClient() -> (client: PIIndexerClient, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "pi-live-\(UUID().uuidString)",
                isDirectory: true
            )
        return (PIIndexerClient(cacheDirectory: directory), directory)
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
        var failures: [String] = []

        for round in 1 ... rounds {
            let (client, directory) = freshClient()
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
                if case let .success(values) = operation.result,
                   values.count == Set(requested).count {
                    marketCapOK += 1
                } else {
                    failures.append("round \(round) market cap: \(String(describing: operation.result))")
                }
            }

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
                "market cap \(marketCapOK)/\(rounds)"
        )
        for failure in failures {
            print("PI live failure: \(failure)")
        }
        XCTAssertEqual(assetsOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(poolsOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(fiatOK, rounds, failures.joined(separator: "; "))
        XCTAssertEqual(marketCapOK, rounds, failures.joined(separator: "; "))
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
