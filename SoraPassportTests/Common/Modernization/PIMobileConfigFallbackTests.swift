// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import XCTest
@testable import SoraPassport

/// The deployed PI indexer may run an older schema without the
/// `mobileConfig` feature-flag fields. The app must then read the base
/// config with a schema-compatible query and keep every optional feature off,
/// without surfacing an error.
final class PIMobileConfigFallbackTests: XCTestCase {
    private final class StubProtocol: URLProtocol {
        static var responder: ((String) -> (status: Int, body: String))?
        static var queryResponder: ((String, String) -> (status: Int, body: String))?
        static var operations: [String] = []
        private static let lock = NSLock()

        override class func canInit(with _: URLRequest) -> Bool { true }

        override class func canonicalRequest(
            for request: URLRequest
        ) -> URLRequest {
            request
        }

        override func startLoading() {
            let body = Self.body(of: request)
            let object = (try? JSONSerialization.jsonObject(with: body))
                as? [String: Any]
            let operation = object?["operationName"] as? String ?? ""
            let query = object?["query"] as? String ?? ""
            Self.lock.lock()
            Self.operations.append(operation)
            let responder = Self.responder
            let queryResponder = Self.queryResponder
            Self.lock.unlock()
            let (status, text) = queryResponder?(operation, query)
                ?? responder?(operation)
                ?? (500, "{}")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: Data(text.utf8))
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

    private static let baseConfig = """
    "blockExplorerUrl":"https://sorametrics.org/sorav2?tab=extrinsics&q={transaction}",\
    "substrateTypesUrl":null,\
    "nodes":[{"name":"Sora","address":"wss://mof2.sora.org"}]
    """

    private var health: String {
        let now = Int(Date().timeIntervalSince1970)
        return """
        {"data":{"_health":{"ok":true,"repositoryReady":true,\
        "service":"polkaswap-indexer","serviceId":"pi.soramitsu.io",\
        "schemaVersion":1,"ecosystem":"sora2","chainId":"sora:mainnet",\
        "network":"mainnet","publicBaseUrl":"https://pi.soramitsu.io/graphql",\
        "readOnly":true,"workerAvailable":true,"workerReady":true,\
        "workerLatestFinalizedBlock":27974318,"workerLatestIndexedBlock":27974317,\
        "workerLag":1,"workerReadinessReason":null,"workerLifecycle":"running",\
        "workerStartupComplete":true,"workerLastSuccessfulIndexTimestamp":\(now),\
        "workerLastError":null,"workerLastErrorTimestamp":null}}}
        """
    }

    private func client() -> PIIndexerClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        configuration.urlCache = nil
        return PIIndexerClient(session: URLSession(configuration: configuration))
    }

    override func setUp() {
        super.setUp()
        StubProtocol.operations = []
    }

    override func tearDown() {
        StubProtocol.responder = nil
        StubProtocol.queryResponder = nil
        super.tearDown()
    }

    func testOlderSchemaFallsBackToBaseConfigWithEveryFeatureOff() async throws {
        let health = self.health
        StubProtocol.responder = { operation in
            switch operation {
            case "MobileHealth":
                return (200, health)
            case "MobileConfig":
                // What the older deployed schema answers.
                return (200, """
                {"errors":[{"message":"Cannot query field \\"nexusAvailable\\" on type \\"MobileConfig\\".",\
                "extensions":{"code":"GRAPHQL_VALIDATION_FAILED"}}]}
                """)
            case "MobileConfigBase":
                return (200, "{\"data\":{\"mobileConfig\":{\(Self.baseConfig)}}}")
            default:
                return (500, "{}")
            }
        }

        let read = try await client().qualifiedMobileConfig(requireLive: true)

        XCTAssertEqual(read.qualification?.source, .live)
        XCTAssertEqual(read.value.nodes.map(\.name), ["Sora"])
        XCTAssertFalse(read.value.nexusAvailable)
        XCTAssertFalse(read.value.nexusSendsAvailable)
        XCTAssertFalse(read.value.polkamarktVisible)
        XCTAssertFalse(read.value.polkamarktMutationsAvailable)
        XCTAssertFalse(read.value.tairaDefaultVisible)
        XCTAssertTrue(StubProtocol.operations.contains("MobileConfig"))
        XCTAssertTrue(StubProtocol.operations.contains("MobileConfigBase"))
    }

    func testHTTP400ValidationFailureAlsoFallsBack() async throws {
        let health = self.health
        StubProtocol.responder = { operation in
            switch operation {
            case "MobileHealth":
                return (200, health)
            case "MobileConfig":
                return (400, """
                {"errors":[{"message":"Cannot query field","extensions":{"code":"GRAPHQL_VALIDATION_FAILED"}}]}
                """)
            case "MobileConfigBase":
                return (200, "{\"data\":{\"mobileConfig\":{\(Self.baseConfig)}}}")
            default:
                return (500, "{}")
            }
        }

        let read = try await client().qualifiedMobileConfig(requireLive: true)

        XCTAssertFalse(read.value.polkamarktVisible)
        XCTAssertFalse(read.value.tairaDefaultVisible)
    }

    func testCurrentSchemaKeepsServerFlags() async throws {
        let health = self.health
        StubProtocol.responder = { operation in
            switch operation {
            case "MobileHealth":
                return (200, health)
            case "MobileConfig":
                return (200, """
                {"data":{"mobileConfig":{\(Self.baseConfig),\
                "nexusAvailable":true,"nexusSendsAvailable":false,\
                "polkamarktVisible":true,"polkamarktMutationsAvailable":false,\
                "tairaDefaultVisible":true}}}
                """)
            default:
                return (500, "{}")
            }
        }

        let read = try await client().qualifiedMobileConfig(requireLive: true)

        XCTAssertTrue(read.value.nexusAvailable)
        XCTAssertTrue(read.value.polkamarktVisible)
        XCTAssertFalse(StubProtocol.operations.contains("MobileConfigBase"))
    }

    func testOtherFailuresAreNotMaskedByTheFallback() async throws {
        StubProtocol.responder = { _ in (503, "{}") }

        do {
            _ = try await client().qualifiedMobileConfig(requireLive: true)
            XCTFail("An unavailable PI must not produce a config")
        } catch {
            XCTAssertFalse(StubProtocol.operations.contains("MobileConfigBase"))
        }
    }

    func testOnlySchemaErrorsSelectTheFallback() {
        XCTAssertTrue(
            PIIndexerClient.indicatesUnsupportedSchema(.graphQLErrors)
        )
        XCTAssertTrue(
            PIIndexerClient.indicatesUnsupportedSchema(.httpStatus(400))
        )
        XCTAssertFalse(
            PIIndexerClient.indicatesUnsupportedSchema(.httpStatus(503))
        )
        XCTAssertFalse(
            PIIndexerClient.indicatesUnsupportedSchema(.invalidResponse)
        )
    }

    func testReferrerRewardsFallBackToIdentifierOrder() async throws {
        let health = self.health
        let referrer = "cnRuMQ4o6DRBVKZpzJdFDW4tg2tDN8MKfxagwX5sRYF9mytEC"
        var orders: [String] = []
        StubProtocol.queryResponder = { operation, query in
            switch operation {
            case "MobileHealth":
                return (200, health)
            case "MobileReferrerRewards":
                if query.contains("TIMESTAMP_DESC") {
                    orders.append("timestamp")
                    // What the deployed public query plan answers.
                    return (200, """
                    {"errors":[{"message":"referrerRewards orderBy field timestamp is not supported by the public query plan",\
                    "extensions":{"code":"BAD_USER_INPUT"}}],"data":null}
                    """)
                }
                orders.append("id")
                return (200, """
                {"data":{"referrerRewards":{"nodes":[{"id":"r1","referral":"cnReferral",\
                "referrer":"\(referrer)","blockHeight":"27974000","timestamp":1791571000,\
                "amount":"1000"}],"pageInfo":{"hasNextPage":false,"hasPreviousPage":false,\
                "startCursor":null,"endCursor":null},"totalCount":1}}}
                """)
            default:
                return (500, "{}")
            }
        }

        let rewards = try await client().allReferrerRewards(
            address: referrer,
            pageSize: 10,
            maximumPages: 2
        )

        XCTAssertEqual(rewards.map(\.id), ["r1"])
        XCTAssertEqual(orders, ["timestamp", "id"])
    }
}
