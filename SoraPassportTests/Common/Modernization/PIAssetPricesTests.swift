import XCTest
@testable import SoraPassport

final class PIAssetPricesTests: XCTestCase {
    override func tearDown() {
        AdvancingIndexerStub.reset()
        super.tearDown()
    }

    func testPricesLoadWhilePIKeepsIndexingNewBlocks() async throws {
        // PI indexes a SORA block every 6 seconds. The pinned walk needs a
        // health read before and after every page, so on mainnet it never
        // finished and the wallet showed no price at all.
        let client = PIIndexerClient(session: AdvancingIndexerStub.session())

        do {
            _ = try await client.allAssets(pageSize: 2)
            XCTFail("A walk pinned to one block cannot finish while PI moves")
        } catch {}

        AdvancingIndexerStub.reset()
        let assets = try await client.allAssetMarketData(pageSize: 2)

        XCTAssertEqual(assets.map(\.id), AdvancingIndexerStub.assetIds)
        XCTAssertEqual(assets.map { $0.priceUSD?.rawValue }, ["4.2", "0.000001", nil])
        XCTAssertEqual(assets.map { $0.liquidity?.rawValue }, ["1000", "0", "7"])
        XCTAssertEqual(assets.map(\.priceChangeDay), [-1.5, 0, nil])
        XCTAssertEqual(
            AdvancingIndexerStub.operations,
            ["MobileHealth", "MobileAssetMarketData", "MobileAssetMarketData"]
        )
    }
}

/// Answers like pi.soramitsu.io, except that every health read reports one
/// more indexed block, as mainnet does every 6 seconds.
private final class AdvancingIndexerStub: URLProtocol {
    static let assetIds = [
        "0x0200000000000000000000000000000000000000000000000000000000000000",
        "0x0200040000000000000000000000000000000000000000000000000000000000",
        "0x0200050000000000000000000000000000000000000000000000000000000000",
    ]
    private static let lock = NSLock()
    private static var indexedBlock = 28_000_000
    private static var recordedOperations: [String] = []

    static var operations: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedOperations
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        recordedOperations = []
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdvancingIndexerStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let request = Self.requestJSON(request)
        let operation = request["operationName"] as? String ?? ""
        let variables = request["variables"] as? [String: Any] ?? [:]
        let data: Data
        switch operation {
        case "MobileHealth":
            data = Self.health()
        default:
            data = Self.assetsPage(after: variables["after"] as? String)
        }
        Self.lock.lock()
        Self.recordedOperations.append(operation)
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Content-Length": "\(data.count)"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func requestJSON(_ request: URLRequest) -> [String: Any] {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }

    private static func health() -> Data {
        lock.lock()
        indexedBlock += 1
        let block = indexedBlock
        lock.unlock()
        let now = Int(Date().timeIntervalSince1970)
        return Data("""
        {"data":{"_health":{"ok":true,"repositoryReady":true,"service":"polkaswap-indexer",\
        "serviceId":"pi.soramitsu.io","schemaVersion":1,"ecosystem":"sora2","chainId":"sora:mainnet",\
        "network":"mainnet","publicBaseUrl":"https://pi.soramitsu.io/graphql","readOnly":true,\
        "workerAvailable":true,"workerReady":true,"workerLatestFinalizedBlock":\(block),\
        "workerLatestIndexedBlock":\(block),"workerLag":0,"workerReadinessReason":null,\
        "workerLifecycle":"running","workerStartupComplete":true,\
        "workerLastSuccessfulIndexTimestamp":\(now),"workerLastError":null,"workerLastErrorTimestamp":null}}}
        """.utf8)
    }

    private static func assetsPage(after: String?) -> Data {
        let nodes: String
        let pageInfo: String
        if after == nil {
            nodes = """
            {"id":"\(assetIds[0])","priceUSD":"4.2","liquidity":"1000","priceChangeDay":-1.5},\
            {"id":"\(assetIds[1])","priceUSD":"0.000001","liquidity":"0","priceChangeDay":0}
            """
            pageInfo = #"{"hasNextPage":true,"hasPreviousPage":false,"startCursor":"c1","endCursor":"c2"}"#
        } else {
            nodes = #"{"id":"\#(assetIds[2])","priceUSD":null,"liquidity":"7","priceChangeDay":null}"#
            pageInfo = #"{"hasNextPage":false,"hasPreviousPage":true,"startCursor":"c3","endCursor":"c3"}"#
        }
        return Data("""
        {"data":{"assets":{"nodes":[\(nodes)],"pageInfo":\(pageInfo),"totalCount":3}}}
        """.utf8)
    }
}
