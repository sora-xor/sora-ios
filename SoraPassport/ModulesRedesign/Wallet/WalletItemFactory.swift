import Foundation
import RobinHood
import CommonWallet
import SoraUIKit
import SoraFoundation
import SCard

protocol WalletItemFactoryProtocol: AnyObject {
    
    func createAccountItem(with walletViewModel: RedesignWalletViewModel,
                           view: RedesignWalletViewProtocol?,
                           wireframe: RedesignWalletWireframeProtocol?,
                           feeProvider: FeeProviderProtocol,
                           assetManager: AssetManagerProtocol,
                           assetsProvider: AssetProviderProtocol,
                           fiatService: FiatServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           accountRepository: AnyDataProviderRepository<AccountItem>,
                           reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?) -> SoramitsuTableViewItemProtocol

    func createSoraCardItem(with walletViewModel: RedesignWalletViewModelProtocol,
                            service: SCard) -> SoramitsuTableViewItemProtocol

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
    
    func createInviteFriendsItem(with walletViewModel: RedesignWalletViewModelProtocol) -> SoramitsuTableViewItemProtocol
}

final class WalletItemFactory: WalletItemFactoryProtocol {
    
    func createAccountItem(with walletViewModel: RedesignWalletViewModel,
                           view: RedesignWalletViewProtocol?,
                           wireframe: RedesignWalletWireframeProtocol?,
                           feeProvider: FeeProviderProtocol,
                           assetManager: AssetManagerProtocol,
                           assetsProvider: AssetProviderProtocol,
                           fiatService: FiatServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           accountRepository: AnyDataProviderRepository<AccountItem>,
                           reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?) -> SoramitsuTableViewItemProtocol {
        let currentAccount = SelectedWalletSettings.shared.currentAccount
        var accountName = currentAccount?.username ?? ""
        if accountName.isEmpty {
            accountName = currentAccount?.address ?? ""
        }
        
        let accountItem: AccountTableViewItem = AccountTableViewItem(accountName: accountName)
        accountItem.scanQRHandler = { [weak self] in
            guard let view = view?.controller else { return }
            
            let completion: (ScanQRResult) -> Void = { [weak self] result in
                guard let self = self else { return }
                
                if let amount = result.receiverInfo?.amount {
                    feeProvider.getFee(for: .outgoing) { fee in
                        wireframe?.showConfirmSendingAsset(on: view,
                                                           assetId: result.receiverInfo?.assetId ?? .xor,
                                                           walletService: WalletService(operationFactory: networkFacade),
                                                           assetManager: assetManager,
                                                           fiatService: fiatService,
                                                           recipientAddress: result.firstName,
                                                           firstAssetAmount: amount.decimalValue,
                                                           fee: fee,
                                                           assetsProvider: assetsProvider)
                    }
                    
                    return
                }
                wireframe?.showSend(on: view,
                                    selectedTokenId: result.receiverInfo?.assetId ?? .xor,
                                    selectedAddress: result.firstName,
                                    fiatService: fiatService,
                                    assetManager: assetManager,
                                    providerFactory: providerFactory,
                                    networkFacade: networkFacade,
                                    assetsProvider: assetsProvider,
                                    qrEncoder: qrEncoder,
                                    sharingFactory: sharingFactory)
            }
            
            wireframe?.showScanQR(on: view,
                                  networkFacade: networkFacade,
                                  assetManager: assetManager,
                                  qrEncoder: qrEncoder,
                                  sharingFactory: sharingFactory,
                                  assetsProvider: assetsProvider,
                                  completion: completion)
        }
        
        accountItem.updateHandler = { [weak accountItem, weak self] in
            guard let accountItem = accountItem else { return }
            reloadItem?([accountItem])
        }

        accountItem.accountHandler = { [weak self] item in
            guard let view = view?.controller else { return }
            
            wireframe?.showManageAccount(on: view, completion: { [weak item] in
                
                let persistentOperation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
                
                persistentOperation.completionBlock = { [weak self] in
                    guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
                    
                    let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
                    let selectedAccount =  accounts.first { $0.address == selectedAccountAddress }
                    var selectedAccountName = selectedAccount?.username ?? ""
                    
                    if selectedAccountName.isEmpty {
                        selectedAccountName = selectedAccount?.address ?? ""
                    }
                    item?.accountName = selectedAccountName
                    
                    if let item = item {
                        reloadItem?([item])
                    }
                }
                OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
            })
        }
        
        return accountItem
    }
    
    func createSoraCardItem(with walletViewModel: RedesignWalletViewModelProtocol,
                            service: SCard) -> SoramitsuTableViewItemProtocol {
        let soraCardItem = SCCardItem(
            service: service
        ) { [weak walletViewModel] in
                guard let walletViewModel = walletViewModel else { return }
                walletViewModel.closeSC()
                walletViewModel.updateItems()
        } onCard: { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            if let isReachable = ReachabilityManager.shared?.isReachable, isReachable {
                walletViewModel.showSoraCardDetails()
            } else {
                walletViewModel.showInternerConnectionAlert()
            }
        }

        return soraCardItem
    }
    
    func createInviteFriendsItem(with walletViewModel: RedesignWalletViewModelProtocol) -> SoramitsuTableViewItemProtocol {

        let friendsItem = FriendsItem()
        
        friendsItem.onClose = { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            walletViewModel.closeReferralProgram()
            walletViewModel.updateItems()
        }
        
        friendsItem.onTap = { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            walletViewModel.showReferralProgram()
        }

        return friendsItem
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
