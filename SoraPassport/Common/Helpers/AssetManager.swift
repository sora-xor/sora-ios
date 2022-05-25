import Foundation
import SoraKeystore
import CommonWallet
import RobinHood

protocol  AssetManagerProtocol: class {
    func assetInfo(for identifier: String) -> AssetInfo?
    func getAssetList() -> [AssetInfo]?
    func updateAssetList(_ list: [AssetInfo])
    func updateWhitelisted(_ list: [AssetInfo])
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset]
    func visibleCount() -> UInt
}

final class AssetManager: AssetManagerProtocol {
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool = false) -> [WalletAsset] {
        let sorted = list.sorted { (asset1, asset2) -> Bool in
            if let lookup1 = lookup[asset1.identifier],
               let lookup2 = lookup[asset2.identifier] {
                return lookup1 < lookup2
            } else {
                return asset1.symbol < asset2.symbol
            }
        }

        if onlyVisible {
            var visible =  sorted.filter { (asset) -> Bool in
                if let info = assetInfo(for: asset.identifier) {
                    if asset.isFeeAsset { return true }
                    return info.visible
                }
                return true
            }
            if let topAsset = visible.first {$0.isFeeAsset},
               let info = assetInfo(for: topAsset.identifier),
               !info.visible {
                    visible.append(WalletAsset.dummyAsset)
                    //fee asset should be always visible, but balance might be hidden, so we need to force reload in capital by altering the array
            }
            return visible
        }
        return sorted
    }

    private var lookup: [String: Int] = [:]
    private var assets: [AssetInfo]?
    
    func assetInfo(for identifier: String) -> AssetInfo? {
        if let assetInfo = assets?.first(where: { $0.assetId == identifier}) {
            return assetInfo
        } else {
            return nil
        }
    }

    func visibleCount() -> UInt {
        UInt(assets?.count  ?? 0)
    }

    func updateWhitelisted(_ list: [AssetInfo]) {
        let updated: [AssetInfo]
        if var assets = self.assets, assets.count != 0 {
            for item in list {
                if var asset = assetInfo(for: item.assetId),
                   let index = assets.firstIndex(where: {$0.assetId == asset.assetId}) {
                    //might be changed in external whitelist
                    asset.icon = item.icon
                    asset.name = item.name
                    asset.symbol = item.symbol
                    assets[index] = asset
                } else {
                    assets.append(item)
                }
            }
            updated = assets
        } else { //first time launch
            updated = list.map { (asset) -> AssetInfo in
                var item = asset
                if WalletAssetId(rawValue: item.assetId) != nil {
                    item.visible = true
                } else {
                    item.visible = false
                }
                return item as AssetInfo
            }.sorted(by: defaultSort)
        }
        updateAssetList(updated)
    }

    func defaultSort(_ a0: AssetInfo, _ a1: AssetInfo) -> Bool {
        let defAssetA = WalletAssetId(rawValue: a0.assetId)
        let defAssetB = WalletAssetId(rawValue: a1.assetId)
        if let assetA = defAssetA?.defaultSort,
           let assetB = defAssetB?.defaultSort {
            return assetA < assetB
        } else if let assetA = defAssetA {
            return true
        } else if let assetB = defAssetB {
            return false
        } else {
            return a0.symbol < a1.symbol
        }
    }

    func updateAssetList(_ list: [AssetInfo]) {
        self.assets = list
        if let assets = assets, assets.count > 0 {
            lookup = (assets.enumerated().reduce(into: [:]) { $0[$1.element.assetId] = $1.offset })
        } else {
            lookup = [:]
        }
        persistAssets()
    }

    private func persistAssets() {
        SettingsManager.shared.set(value: lookup, for: SettingsKey.assetList.rawValue)
        operationManager.enqueue(operations: [saveAllOperation], in: .sync)
    }

    func getAssetList() -> [AssetInfo]? {
        assets
    }

    private var fetchAllOperation: BaseOperation<[AssetInfo]> {
        storage.fetchAllOperation(with: RepositoryFetchOptions())
    }

    private var saveAllOperation: BaseOperation<Void> {
        storage.saveOperation({
            self.assets ?? []
        }, { [] })
    }

    private var storage: AnyDataProviderRepository<AssetInfo>
    private var operationManager: OperationManagerProtocol

    init(storage: AnyDataProviderRepository<AssetInfo>,
         operationManager: OperationManagerProtocol) {
        self.storage = storage
        self.operationManager = operationManager

        let operation = fetchAllOperation
        operation.completionBlock = {
            self.lookup = SettingsManager.shared.value(of: [String: Int].self, for: SettingsKey.assetList.rawValue) ?? [:]
            let assets = try? operation.extractNoCancellableResultData()
            if !self.lookup.isEmpty {
                self.assets = assets?.sorted { (asset1, asset2) -> Bool in
                    if let lookup1 = self.lookup[asset1.identifier],
                       let lookup2 = self.lookup[asset2.identifier] {
                        return lookup1 < lookup2
                    } else {
                        return asset1.symbol < asset2.symbol
                    }
                }
            } else {
                self.assets = assets?.sorted(by: self.defaultSort)
            }

        }
        OperationQueue().addOperations([operation], waitUntilFinished: true)
//not the best solution, but since the ui is anyway blocked by splash interactor, okeyish
    }

    static let shared: AssetManagerProtocol = {
        let storage: CoreDataRepository<AssetInfo, CDAssetInfo> = SubstrateDataStorageFacade.shared.createRepository()
        let operationManager = OperationManagerFacade.sharedManager
        let manager = AssetManager(storage: AnyDataProviderRepository(storage),
                                   operationManager: operationManager)

        return manager
    }()

}
