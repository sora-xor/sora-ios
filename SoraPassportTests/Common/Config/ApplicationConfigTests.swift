import XCTest
import Foundation
import BigInt
import sorawallet
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

    func testXorNameIsCanonicalizedByAssetId() throws {
        let cachedAsset = AssetInfo(
            id: WalletAssetId.xor.rawValue,
            symbol: "XOR",
            chainId: Chain.sora.genesisHash(),
            precision: 18,
            icon: nil,
            displayName: "1M XOR",
            visible: true
        )
        XCTAssertEqual(cachedAsset.name, "XOR")

        let remoteAsset = try JSONDecoder().decode(AssetInfo.self, from: Data(#"""
        {
          "symbol":"XOR",
          "name":"1M XOR",
          "asset_id":"0x0200000000000000000000000000000000000000000000000000000000000000",
          "precision":"18"
        }
        """#.utf8))
        XCTAssertEqual(remoteAsset.name, "XOR")

        XCTAssertEqual(
            AssetInfo.canonicalName(for: WalletAssetId.pswap.rawValue, proposedName: "Polkaswap"),
            "Polkaswap"
        )
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

    func testFiatQueriesAreFilteredAndBoundedToRequestedAssetIds() {
        let assetIds = (0..<141).map { "0x" + String(format: "%064x", $0) }
        let batches = SoraFiatPriceQueryBuilder.batches(
            for: assetIds + [assetIds[0], "invalid-asset-id"]
        )

        XCTAssertEqual(batches.map(\.count), [70, 70, 1])
        XCTAssertEqual(Set(batches.flatMap { $0 }), Set(assetIds))

        let query = SoraFiatPriceQueryBuilder.query(
            assetIds: batches[0],
            cursor: "cursor"
        )
        XCTAssertTrue(query.contains("filter: { and: [{ id: { in:"))
        XCTAssertTrue(query.contains(assetIds[0]))
        XCTAssertTrue(query.contains("after: \"cursor\""))
        XCTAssertFalse(query.contains("invalid-asset-id"))
    }

    func testFiatQueryBuilderRejectsEmptyAndMalformedRequests() {
        XCTAssertTrue(SoraFiatPriceQueryBuilder.batches(for: []).isEmpty)
        XCTAssertTrue(
            SoraFiatPriceQueryBuilder.batches(for: ["0x02", "not-an-id"]).isEmpty
        )
    }

    func testApyPairKeyIsStableAcrossAssetOrderAndCase() {
        let xor = WalletAssetId.xor.rawValue
        let pswap = WalletAssetId.pswap.rawValue

        XCTAssertEqual(
            SoraApyPairKey.make(baseAssetId: xor, targetAssetId: pswap),
            SoraApyPairKey.make(baseAssetId: pswap.uppercased(), targetAssetId: xor)
        )
    }

    func testMapsProductionHistoryElementToWalletHistoryItem() throws {
        let json = Data(#"""
        {
          "id":"0x357177f16f2e7abf1b5780d173392c8157ba0b0d802c3b48aa5a83d665c71dbf",
          "blockHash":"0xc06a7f48afdc6ca167b2c5eb5ce4a9d83cb92c90510c9c4fcc2071e5569631fd",
          "module":"liquidityProxy",
          "method":"swap",
          "address":"cnSN33HpCwZqxQ4iVf3voVUJ9jx9wPULVMXw6iVgPgkeneNtM",
          "timestamp":1783361850,
          "networkFee":"100014612589707326",
          "execution":{"success":true},
          "data":{
            "baseAssetId":"0x020004",
            "targetAssetId":"0x020000",
            "baseAssetAmount":"549.647891640506891617",
            "targetAssetAmount":"1",
            "selectedMarket":"PoolXYK"
          }
        }
        """#.utf8)

        let element = try JSONDecoder().decode(SubqueryHistoryElement.self, from: json)
        let item = SoraIndexerHistoryMapper.map(element, address: element.address)

        XCTAssertEqual(item.id, element.identifier)
        XCTAssertEqual(item.module, "liquidityProxy")
        XCTAssertEqual(item.method, "swap")
        XCTAssertEqual(item.timestamp, "1783361850")
        XCTAssertEqual(item.networkFee, "100014612589707326")
        XCTAssertTrue(item.success)
        XCTAssertEqual(
            item.data?.first(where: { $0.paramName == "selectedMarket" })?.paramValue,
            "PoolXYK"
        )
    }
}
