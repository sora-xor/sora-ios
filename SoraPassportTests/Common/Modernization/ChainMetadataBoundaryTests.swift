import Foundation
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

final class ChainMetadataBoundaryTests: XCTestCase {
    private func chain(name: String = "Sora", options: [ChainOptions]? = nil, types: ChainModel.TypesSettings? = nil) -> ChainModel {
        ChainModel(chainId: "chain", name: name, nodes: [], addressPrefix: 69, types: types, icon: nil, options: options, iosMinAppVersion: "1.0")
    }
    private func asset(_ id: String, symbol: String) throws -> AssetModel {
        AssetInfo(id: id, symbol: symbol, chainId: "chain", precision: 18, icon: nil, displayName: symbol, visible: true)
    }
    func testChainAssetIdentityIncludesChainAssetAndAccount() throws {
        let model = chain(); let token = try asset(WalletAssetId.xor.rawValue, symbol: "XOR")
        let value = ChainAsset(chain: model, asset: token)
        let account = try SoraPassport.AccountId(scaleDecoder: ScaleDecoder(data: Data(repeating: 0xab, count: 32)))
        XCTAssertEqual(value.uniqueKey(accountId: account), token.id + ":chain:" + String(repeating: "ab", count: 32))
        XCTAssertEqual(value.currencyId, "XOR"); XCTAssertEqual(value.chainAssetType, .normal)
        XCTAssertEqual(value.chainAssetId, ChainAssetId(chainId: "chain", assetId: token.id))
        XCTAssertEqual(value.storagePath.moduleName, "System"); XCTAssertEqual(value.storagePath.itemName, "Account")
        XCTAssertEqual(Set([value, ChainAsset(chain: model, asset: token)]).count, 1)
        let encoded = try JSONEncoder().encode(value.chainAssetId)
        XCTAssertEqual(try JSONDecoder().decode(ChainAssetId.self, from: encoded), value.chainAssetId)
    }
    func testUtilityAssetsRemainBoundToTheirOwningChain() throws {
        let model = chain()
        let xor = ChainAssetModel(assetId: WalletAssetId.xor.rawValue, type: .normal, asset: try asset(WalletAssetId.xor.rawValue, symbol: "XOR"), chain: model)
        let other = ChainAssetModel(assetId: "other", type: .normal, asset: try asset("other", symbol: "OTHER"), chain: model)
        model.assets = [xor, other]
        XCTAssertEqual(model.utilityAssets(), [xor]); XCTAssertEqual(model.utilityChainAssets().map(\.asset.id), [xor.assetId])
        XCTAssertEqual(Set(model.chainAssets.map(\.asset.id)), [xor.assetId, "other"])
        XCTAssertTrue(model.chainAssets.allSatisfy { $0.chain === model })
    }
    func testChainCapabilityFlagsAreIndependentAndDefaultOff() {
        let empty = chain()
        XCTAssertFalse(empty.isEthereumBased); XCTAssertFalse(empty.isTestnet); XCTAssertFalse(empty.isTipRequired); XCTAssertFalse(empty.hasCrowdloans)
        for option in [ChainOptions.ethereumBased, .testnet, .tipRequired, .crowdloans] {
            let model = chain(options: [option])
            XCTAssertEqual(model.isEthereumBased, option == .ethereumBased); XCTAssertEqual(model.isTestnet, option == .testnet)
            XCTAssertEqual(model.isTipRequired, option == .tipRequired); XCTAssertEqual(model.hasCrowdloans, option == .crowdloans)
        }
        XCTAssertTrue(empty.isSupported); XCTAssertEqual(empty.erasPerDay, 1); XCTAssertEqual(empty.identifier, "chain")
    }
    func testStakingHistorySupportUsesKnownChainNamesCaseInsensitively() {
        for name in ["Polkadot", "POLKADOT", "Kusama", "WESTEND"] { XCTAssertTrue(chain(name: name).hasStakingRewardHistory) }
        XCTAssertFalse(chain(name: "Sora").hasStakingRewardHistory)
        XCTAssertTrue(chain(name: "Westend").isWestend); XCTAssertFalse(chain(name: "Westend").isPolkadotOrKusama)
        XCTAssertEqual(chain(name: "Polkadot").erasPerDay, 1)
    }
    func testRuntimeTypesUsageDistinguishesExtensionFromCompleteOverride() throws {
        XCTAssertEqual(chain().typesUsage, .onlyCommon)
        let url = try XCTUnwrap(URL(string: "https://example.org/types.json"))
        XCTAssertEqual(chain(types: .init(url: url, overridesCommon: false)).typesUsage, .both)
        XCTAssertEqual(chain(types: .init(url: url, overridesCommon: true)).typesUsage, .onlyOwn)
    }
    func testNodeReplacementProducesIndependentModelsWithoutLosingIdentity() throws {
        let model = chain(); let node = ChainNodeModel(url: try XCTUnwrap(URL(string: "wss://node.example.org")), name: "Node", apikey: nil)
        let selected = model.replacingSelectedNode(node)
        XCTAssertNil(model.selectedNode); XCTAssertEqual(selected.selectedNode, node); XCTAssertEqual(selected.chainId, model.chainId)
        XCTAssertNotEqual(model, selected); XCTAssertEqual(Set([model, selected]).count, 2)
        let custom = selected.replacingCustomNodes([node, node])
        XCTAssertEqual(custom.customNodes, [node]); XCTAssertNil(selected.customNodes); XCTAssertEqual(custom.selectedNode, node)
        XCTAssertEqual(custom.name, selected.name); XCTAssertEqual(custom.addressPrefix, selected.addressPrefix)
    }
    func testUnknownChainOptionsDecodeAsUnsupportedForForwardCompatibility() throws {
        for option in ["ethereumBased", "testnet", "crowdloans", "orml", "tipRequired", "unsupported", "futureOption"] {
            let value = try JSONDecoder().decode(ChainOptions.self, from: Data("\"\(option)\"".utf8))
            XCTAssertEqual(value, ChainOptions(rawValue: option) ?? .unsupported)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(ChainOptions.self, from: Data("3".utf8)))
    }
    func testExplorerLinksPreserveAccountAndExtrinsicIdentity() {
        let model = chain(name: "polkadot")
        XCTAssertEqual(model.polkascanAddressURL("account")?.absoluteString, "https://polkascan.io/polkadot/account/account")
        XCTAssertEqual(model.subscanAddressURL("account")?.absoluteString, "https://polkadot.subscan.io/account/account")
        XCTAssertEqual(model.subscanExtrinsicUrl("0x1234")?.absoluteString, "https://polkadot.subscan.io/extrinsic/0x1234")
        XCTAssertEqual(Chain.polkadot.polkascanExtrinsicURL("0x1234")?.absoluteString, "https://polkascan.io/polkadot/extrinsic/0x1234")
        XCTAssertEqual(Chain.polkadot.polkascanAddressURL("account"), model.polkascanAddressURL("account"))
        XCTAssertEqual(Chain.polkadot.subscanExtrinsicURL("0x1234"), model.subscanExtrinsicUrl("0x1234"))
        XCTAssertEqual(Chain.polkadot.subscanAddressURL("account"), model.subscanAddressURL("account"))
        XCTAssertNil(Chain.sora.polkascanExtrinsicURL("hash")); XCTAssertNil(Chain.sora.polkascanAddressURL("account"))
        XCTAssertNil(Chain.sora.subscanExtrinsicURL("hash")); XCTAssertNil(Chain.sora.subscanAddressURL("account"))
    }
    func testChainDefaultsAndExplicitSettingsOverridesRemainConsistent() {
        let settings = SettingsManager.shared
        let keys = [SettingsKey.externalGenesis.rawValue, SettingsKey.externalExistentialDeposit.rawValue, SettingsKey.externalPrefix.rawValue]
        let previous = keys.map { settings.anyValue(for: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { settings.set(anyValue: value, for: key) } else { settings.removeValue(for: key) }
            }
        }
        settings.externalGenesis = nil; settings.externalExistentialDeposit = nil; settings.externalAddressPrefix = nil
        XCTAssertEqual(Chain.sora.addressType(), 69); XCTAssertEqual(Chain.polkadot.addressType(), 69)
        XCTAssertEqual(Chain.sora.existentialDeposit(), 0); XCTAssertEqual(Chain.polkadot.existentialDeposit(), 1)
        XCTAssertEqual(Chain.sora.genesisHash(), "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5")
        XCTAssertEqual(Chain.polkadot.genesisHash(), "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3")
        settings.externalGenesis = "custom-genesis"; settings.externalExistentialDeposit = 3; settings.externalAddressPrefix = 42
        for model in [Chain.sora, .polkadot] { XCTAssertEqual(model.genesisHash(), "custom-genesis"); XCTAssertEqual(model.existentialDeposit(), 3); XCTAssertEqual(model.addressType(), 42) }
    }
    func testRuntimeTypeResourcesAreBundledAndRemotePathsHaveExpectedNames() throws {
        for model in [Chain.sora, .polkadot] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(model.preparedDefaultTypeDefPath())))
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(model.preparedNetworkTypeDefPath())))
            XCTAssertEqual(model.typeDefDefaultFileURL()?.lastPathComponent, "default.json")
            XCTAssertFalse(model.repoPrefix.isEmpty)
        }
        XCTAssertEqual(Chain.polkadot.typeDefNetworkFileURL()?.lastPathComponent, "polkadot.json")
        XCTAssertEqual(Chain.sora.typeDefNetworkFileURL(), ApplicationConfig.shared.commonTypesURL)
    }
}
