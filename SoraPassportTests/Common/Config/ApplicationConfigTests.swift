import XCTest
import Foundation
import BigInt
@testable import SoraPassport

class ApplicationConfigTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testConfigurationIntegrity() {
        XCTAssertNotNil(ApplicationConfig(configName: "Dev"))
        XCTAssertNotNil(ApplicationConfig(configName: "Release"))
        XCTAssertNotNil(ApplicationConfig(configName: "Test"))
        XCTAssertNotNil(ApplicationConfig(configName: "Staging"))
        XCTAssertNotNil(ApplicationConfig.shared)

        XCTAssertNoThrow(ApplicationConfig.shared.termsURL)
        XCTAssertNoThrow(ApplicationConfig.shared.version)
    }

    func testSoraNetworkEndpoints() {
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL.absoluteString, "https://pi.soramitsu.io/graphql")
        XCTAssertEqual(ApplicationConfig.shared.subqueryUrl, ApplicationConfig.shared.polkaswapIndexerURL)

        let nodes = ApplicationConfig.shared.defaultChainNodes
        XCTAssertEqual(Set(nodes.map(\.url.absoluteString)), [
            "wss://mof2.sora.org",
            "wss://ws.mof.sora.org"
        ])
        XCTAssertTrue(nodes.allSatisfy { $0.name == "Sora" })
        XCTAssertTrue(nodes.allSatisfy { $0.apikey == nil })
    }

    func testRemoteConfigFallsBackFromInvalidURLs() {
        let fallback = ApplicationConfig.shared.polkaswapIndexerURL
        let config = RemoteConfig(
            polkaswapIndexerUrlString: "://not-a-valid-url",
            typesUrlString: "://not-a-valid-types-url",
            defaultNodes: []
        )

        XCTAssertEqual(config.polkaswapIndexerURL, fallback)
        XCTAssertEqual(config.subqueryURL, fallback)
        XCTAssertNil(config.typesURL)
        XCTAssertTrue(config.defaultNodes.isEmpty)
    }

    func testAppConfigExplorerURLsUseSorametrics() throws {
        let root = try repositoryRoot()
        let plistURL = root.appendingPathComponent("SoraPassport/Configs/appConfig.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let strings = collectStrings(from: plist)
        let sorametricsURLs = strings.filter {
            $0 == "https://sorametrics.org/sorav2?tab=extrinsics&q={transaction}"
        }

        XCTAssertEqual(sorametricsURLs.count, 4)
        XCTAssertFalse(strings.contains { $0.contains("subscan") })
    }

    func testCocoaPodsArtifactsAreRemovedFromProject() throws {
        let root = try repositoryRoot()
        let fileManager = FileManager.default

        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Podfile").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Podfile.lock").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Pods").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("SoraPassport.xcworkspace").path))

        let projectFile = root.appendingPathComponent("SoraPassport.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectFile)
        XCTAssertFalse(project.contains("PODS_ROOT"))
        XCTAssertFalse(project.contains("[CP]"))
        XCTAssertFalse(project.contains("Pods-"))
        XCTAssertFalse(project.contains("pod install"))
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            if fileManager.fileExists(atPath: directory.appendingPathComponent("SoraPassport.xcodeproj").path) {
                return directory
            }

            directory.deleteLastPathComponent()
        }

        throw NSError(domain: "ApplicationConfigTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to locate repository root from \(#filePath)"
        ])
    }

    private func collectStrings(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap(collectStrings)
        }

        if let dictionary = value as? [String: Any] {
            return dictionary.values.flatMap(collectStrings)
        }

        return []
    }
}

final class RuntimeAccountDataTests: XCTestCase {
    func testDecodesCurrentRuntimeAccountData() throws {
        let json = Data(#"""
        {
            "nonce":"1",
            "consumers":"2",
            "providers":"3",
            "sufficients":"1",
            "data":{"free":"100","reserved":"7","frozen":"25","flags":"0"}
        }
        """#.utf8)

        let account = try JSONDecoder().decode(AccountInfo.self, from: json)

        XCTAssertEqual(account.data.free, BigUInt(100))
        XCTAssertEqual(account.data.reserved, BigUInt(7))
        XCTAssertEqual(account.data.miscFrozen, BigUInt(25))
        XCTAssertEqual(account.data.feeFrozen, .zero)
        XCTAssertEqual(account.data.locked, BigUInt(25))
        XCTAssertEqual(account.data.available, BigUInt(75))
    }

    func testDecodesLegacyRuntimeAccountData() throws {
        let json = Data(#"""
        {
            "nonce":"1",
            "consumers":"2",
            "providers":"3",
            "data":{"free":"100","reserved":"7","miscFrozen":"11","feeFrozen":"13"}
        }
        """#.utf8)

        let account = try JSONDecoder().decode(AccountInfo.self, from: json)

        XCTAssertEqual(account.data.miscFrozen, BigUInt(11))
        XCTAssertEqual(account.data.feeFrozen, BigUInt(13))
        XCTAssertEqual(account.data.locked, BigUInt(13))
    }

    func testDynamicAccountDataUsesCurrentFrozenField() throws {
        let json = Data(#"""
        {
            "nonce":"1",
            "consumers":"2",
            "providers":"3",
            "data":{"free":"10","reserved":"0","frozen":"25","flags":"0"}
        }
        """#.utf8)

        let account = try JSONDecoder().decode(DyAccountInfo.self, from: json)

        XCTAssertEqual(account.data.locked, BigUInt(25))
        XCTAssertEqual(account.data.available, .zero)
    }

    func testRejectsAccountDataWithoutAnyFrozenRepresentation() {
        let json = Data(#"""
        {
            "nonce":"1",
            "consumers":"2",
            "providers":"3",
            "data":{"free":"100","reserved":"7"}
        }
        """#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(AccountInfo.self, from: json))
    }
}

final class SoraIndexerResponseTests: XCTestCase {
    private struct AssetNode: Decodable {
        let id: String
        let priceUSD: String
    }

    func testDecodesProductionIndexerConnectionShape() throws {
        let json = Data(#"""
        {
          "data": {
            "entities": {
              "nodes": [{"id":"0x02","priceUSD":"5.39"}],
              "pageInfo": {"hasNextPage":false,"endCursor":"cursor"}
            }
          }
        }
        """#.utf8)

        let response = try JSONDecoder().decode(
            SubqueryResponse<SoraIndexerEntitiesPayload<AssetNode>>.self,
            from: json
        )

        switch response {
        case let .data(payload):
            XCTAssertEqual(payload.entities.nodes.first?.id, "0x02")
            XCTAssertEqual(payload.entities.nodes.first?.priceUSD, "5.39")
            XCTAssertFalse(payload.entities.pageInfo.hasNextPage)
        case .errors:
            XCTFail("Expected data response")
        }
    }
}
