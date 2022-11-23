import Foundation
import UIKit
import SoraSwiftUI
import CommonWallet

protocol RedesignWalletViewModelProtocol {
    var reloadItem: ((SoramitsuTableViewItemProtocol) -> Void)? { get set }
    func fetchAssets(completion: ([SoramitsuTableViewItemProtocol]) -> Void)
    func updateAssets()
}

final class WalletViewModel {

    var reloadItem: ((SoramitsuTableViewItemProtocol) -> Void)?

    var providerFactory: BalanceProviderFactory
    var assetManager: AssetManagerProtocol
    var coordinator: WalletCoordinator?

    var walletItems: [SoramitsuTableViewItemProtocol] = []

    init(providerFactory: BalanceProviderFactory,
         assetManager: AssetManagerProtocol) {
        self.providerFactory = providerFactory
        self.assetManager = assetManager
    }
}

extension WalletViewModel: RedesignWalletViewModelProtocol {
    func updateAssets() {
        (walletItems.first as? AssetsItem)?.balanceProvider?.refresh()
    }


    func fetchAssets(completion: ([SoramitsuTableViewItemProtocol]) -> Void) {
        walletItems = [ assetsItem() /* pools, staking .... coming soon */ ]
        completion(walletItems)
    }
}

private extension WalletViewModel {
    private func assetsItem() -> SoramitsuTableViewItemProtocol {
        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: assetManager.getAssetList() ?? [], onlyVisible: true)

        let factory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [], assetManager: assetManager)

        let assetsItem = AssetsItem(title: R.string.localizable.liquidAssets(preferredLanguages: .currentLocale),
                                    balanceProvider: balanceProvider,
                                    assetViewModelsFactory: factory)

        assetsItem.updateHandler = { [weak assetsItem, weak self] in
            guard let self = self, let assetsItem = assetsItem else { return }
            self.reloadItem?(assetsItem)
        }

        assetsItem.arrowButtonHandler = { [weak assetsItem, weak self] in
            guard let self = self, let assetsItem = assetsItem else { return }
            assetsItem.isExpand = !assetsItem.isExpand
            self.reloadItem?(assetsItem)
        }

        assetsItem.expandButtonHandler = { [weak self] in
            self?.showFullListAssets()
        }

        return assetsItem
    }
}

private extension WalletViewModel {
    func showFullListAssets() {
        let assets = self.assetManager.getAssetList() ?? []

        let balanceProvider = try? self.providerFactory.createBalanceDataProvider(for: assets, onlyVisible: false)

        let factory = AssetViewModelFactory(walletAssets: assets, assetManager: self.assetManager)

        coordinator?.showFullListAssets(balanceProvider: balanceProvider,
                                        assetManager: self.assetManager,
                                        assetViewModelFactory: factory)
    }
}
