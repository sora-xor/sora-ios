import Foundation
import RobinHood
import CommonWallet
import SoraUIKit
import SoraFoundation
import SCard

protocol WalletItemFactoryProtocol: AnyObject {

    func createSoraCardItem(with walletViewModel: RedesignWalletViewModelProtocol,
                            service: SCard,
                            onClose: (() -> Void)?) -> SoramitsuTableViewItemProtocol

    func createAssetsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                          assetManager: AssetManagerProtocol,
                          assetsProvider: AssetProviderProtocol,
                          fiatService: FiatServiceProtocol) -> SoramitsuTableViewItemProtocol
    
    func createPoolsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                         poolService: PoolsServiceInputProtocol,
                         networkFacade: WalletNetworkOperationFactoryProtocol,
                         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol) -> SoramitsuTableViewItemProtocol
}

final class WalletItemFactory: WalletItemFactoryProtocol {
    
    func createSoraCardItem(with walletViewModel: RedesignWalletViewModelProtocol,
                            service: SCard,
                            onClose: (() -> Void)?) -> SoramitsuTableViewItemProtocol {
        let soraCardItem = SCCardItem(
            service: service
        ) { [weak walletViewModel] in
                walletViewModel?.closeSC()
                onClose?()
        } onCard: { [weak walletViewModel] in
            if let isReachable = ReachabilityManager.shared?.isReachable, isReachable {
                walletViewModel?.showSoraCardDetails()
            } else {
                walletViewModel?.showInternerConnectionAlert()
            }
        }

        return soraCardItem
    }

    func createAssetsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                          assetManager: AssetManagerProtocol,
                          assetsProvider: AssetProviderProtocol,
                          fiatService: FiatServiceProtocol) -> SoramitsuTableViewItemProtocol {
        
        let factory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        let assetsItem = AssetsItem(title: R.string.localizable.liquidAssets(preferredLanguages: .currentLocale),
                                    assetProvider: assetsProvider,
                                    assetManager: assetManager,
                                    fiatService: fiatService,
                                    assetViewModelsFactory: factory)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.liquidAssets(preferredLanguages: locale.rLanguages)
        }
        
        LocalizationManager.shared.addObserver(with: assetsItem) { [weak assetsItem] (_, _) in
            let currentTitle = localizableTitle.value(for: LocalizationManager.shared.selectedLocale)
            assetsItem?.title = currentTitle
        }
        
        assetsItem.updateHandler = { [weak walletViewModel, weak assetsItem] in
            guard let walletViewModel = walletViewModel, let assetsItem = assetsItem else { return }
            walletViewModel.reloadItem?([assetsItem])
        }
        
        assetsItem.arrowButtonHandler = { [weak assetsItem] in
            guard let assetsItem = assetsItem else { return }
            assetsItem.isExpand = !assetsItem.isExpand
            walletViewModel.reloadItem?([assetsItem])
        }
        
        assetsItem.expandButtonHandler = { [weak walletViewModel] in
            walletViewModel?.showFullListAssets()
        }
        
        assetsItem.assetHandler = { [weak assetManager, weak walletViewModel] identifier in
            guard let assetInfo = assetManager?.getAssetList()?.first(where: { $0.identifier == identifier }) else { return }
            walletViewModel?.showAssetDetails(with: assetInfo)
        }
        
        return assetsItem
    }
    
    func createPoolsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                         poolService: PoolsServiceInputProtocol,
                         networkFacade: WalletNetworkOperationFactoryProtocol,
                         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol) -> SoramitsuTableViewItemProtocol {
        
        let factory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                           fiatService: fiatService)
        
        let poolsItem = PoolsItem(title: R.string.localizable.pooledAssets(preferredLanguages: .currentLocale),
                                  poolsService: poolService,
                                  fiatService: fiatService,
                                  poolViewModelsFactory: factory)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.pooledAssets(preferredLanguages: locale.rLanguages)
        }
        
        LocalizationManager.shared.addObserver(with: poolsItem) { [weak poolsItem] (_, _) in
            let currentTitle = localizableTitle.value(for: LocalizationManager.shared.selectedLocale)
            poolsItem?.title = currentTitle
        }
        
        poolService.appendDelegate(delegate: poolsItem)
        
        poolsItem.updateHandler = { [weak poolsItem, weak walletViewModel] in
            guard let walletViewModel = walletViewModel, let poolsItem = poolsItem else { return }
            walletViewModel.reloadItem?([poolsItem])
        }
        
        poolsItem.arrowButtonHandler = { [weak poolsItem] in
            guard let poolsItem = poolsItem else { return }
            poolsItem.isExpand = !poolsItem.isExpand
            walletViewModel.reloadItem?([poolsItem])
        }
        
        poolsItem.expandButtonHandler = { [weak walletViewModel] in
            walletViewModel?.showFullListPools()
        }
        
        poolsItem.poolHandler = { [weak poolService, weak walletViewModel] identifier in
            guard let poolInfo = poolService?.getPool(by: identifier) else { return }
            walletViewModel?.showPoolDetails(with: poolInfo)
        }
        
        return poolsItem
    }
}
