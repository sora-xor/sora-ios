import Foundation
import SoraKeystore
import CommonWallet
import RobinHood

protocol  AssetManagerProtocol: AnyObject {
    func assetInfo(for identifier: String) -> AssetInfo?
    func getAssetList() -> [AssetInfo]?
    func updateAssetList(_ list: [AssetInfo])
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset]
    func visibleCount() -> UInt
    static var networkAssets: [AssetInfo] { get set }
    func setup(for accountSettings: SelectedWalletSettings)
}

final class AssetManager: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = [] //very dirty, bur we need to pass network assets into initialization of the chain.

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let storage: AnyDataProviderRepository<AssetInfo>
    private let operationManager: OperationManagerProtocol
    private let chainProvider: StreamableProvider<ChainModel>
    private let chainId: ChainModel.Id
    private var chain: ChainModel?
    private var settings: AccountSettings?
    private var accountSettings: SelectedWalletSettings? {
        didSet {
            settings = accountSettings?.value?.settings ?? AccountSettings()
        }
    }

    private var assets: [AssetInfo]?

    init(storage: AnyDataProviderRepository<AssetInfo>,
         chainProvider: StreamableProvider<ChainModel>,
         chainId: ChainModel.Id,
         operationManager: OperationManagerProtocol) {
        self.storage = storage
        self.operationManager = operationManager
        self.chainProvider = chainProvider
        self.chainId = chainId

        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )

        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            Logger.shared.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )


        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(chain):
                guard chain.chainId == self.chainId else {
                    return
                }
                self.chain = chain
            case let .update(chain):
                guard chain.chainId == self.chainId else {
                    return
                }
                self.chain = chain
            case let .delete(chainId):
                break
            }
        }
    }

    func setup(for accountSettings: SelectedWalletSettings) {
        self.accountSettings = accountSettings
        Logger.shared.info("ASSET MANAGER SETUP \(chain?.chainAssets)")
        let chainAssets = chain?.chainAssets.map { $0.asset } ?? []
        self.updateWhitelisted(chainAssets)
    }

    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool = false) -> [WalletAsset] {
        let sorted = list.sorted(by: orderSort)

        if onlyVisible {
            var visible =  sorted.filter { (asset) -> Bool in
                if let info = assetInfo(for: asset.identifier) {
                    if asset.isFeeAsset { return true }
                    return info.visible
                }
                return true
            }
            if let topAsset = visible.first { $0.isFeeAsset },
               let info = assetInfo(for: topAsset.identifier),
               info.visible {
                    visible.append(WalletAsset.dummyAsset)
                    //fee asset should be always visible, but balance might be hidden, so we need to force reload in capital by altering the array
            }
            return visible
        }
        return sorted
    }

    private func orderSort(_ asset0: WalletAsset, _ asset1: WalletAsset) -> Bool {
        if let index0 = settings?.orderedAssetIds?.firstIndex {$0 == asset0.identifier },
        let index1 = settings?.orderedAssetIds?.firstIndex {$0 == asset1.identifier } {
            return index0 < index1
        } else {
            return asset0.symbol < asset1.symbol
        }
    }

    func assetInfo(for identifier: String) -> AssetInfo? {
        if let assetInfo = assets?.first(where: { $0.assetId == identifier}) {
            return assetInfo
        } else {
            return nil
        }
    }

    func visibleCount() -> UInt {
        Logger.shared.info("VISIBLE COUNT \(settings?.visibleAssetIds?.count)")
        guard let visibleAssets = settings?.visibleAssetIds,
              visibleAssets.count > 0 else {
            return 1
        }
        return UInt(visibleAssets.count)
    }

    private func defaultSort(_ a0: AssetInfo, _ a1: AssetInfo) -> Bool {
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

    private func updateWhitelisted(_ list: [AssetInfo]) {
        let updated: [AssetInfo]

        if let settings = self.settings,
           let order = settings.orderedAssetIds,  //they are always ordered
           !order.isEmpty {
            updated = order.enumerated().compactMap { identifier in
                if var asset = list.first(where: { $0.identifier == identifier.element }) {
                    if let visibles = settings.visibleAssetIds {
                        asset.visible = visibles.contains(where: { identifier in
                            asset.identifier == identifier
                        })
                    }
                    return asset
                }
                return nil
            }
        } else { //default sort
            updated =  list.sorted(by: defaultSort).map { asset in
                var item = asset
                if WalletAssetId(rawValue: item.assetId) != nil {
                    item.visible = true
                } else {
                    item.visible = false
                }
                return item as AssetInfo
            }
        }
        updateAssetList(updated)
    }
    
    func updateAssetList(_ list: [AssetInfo]) {
        self.assets = list
        Logger.shared.info("ASSETS UPDATE \(self.assets?.count)")
        var newOrder: [String] = []
        var newVisible: [String] = []
        if let assets = assets, assets.count > 0 {
            newOrder = assets.enumerated().map { $0.element.identifier }
            newVisible = assets.compactMap { return $0.visible ? $0.identifier : nil}
        }
        settings?.orderedAssetIds = newOrder
        settings?.visibleAssetIds = newVisible
        self.persistAssets()
    }

    private func persistAssets() {
        guard let account = accountSettings?.value,
              let updatedSettings = settings
        else {
            return
        }

        let updatedAccount = account.replacingSettings(updatedSettings)

        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            self?.accountSettings?.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    DispatchQueue.main.async {

                    }
                case .failure:
                    break
                }
            }
        }

        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.addOperation(saveOperation)
    }

    func getAssetList() -> [AssetInfo]? {
        assets
    }
}
