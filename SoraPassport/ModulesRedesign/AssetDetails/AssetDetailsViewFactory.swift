import Foundation
import RobinHood
import CommonWallet

protocol AssetDetailsViewFactoryProtocol: AnyObject {
    static func createView(assetInfo: AssetInfo,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           assetViewModelFactory: AssetViewModelFactoryProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           poolViewModelsFactory: PoolViewModelFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           networkFacade: WalletNetworkOperationFactoryProtocol?,
                           accountId: String,
                           address: String,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           referralFactory: ReferralsOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?) -> AssetDetailsViewController?
}

final class AssetDetailsViewFactory: AssetDetailsViewFactoryProtocol {
    static func createView(assetInfo: AssetInfo,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           assetViewModelFactory: AssetViewModelFactoryProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           poolViewModelsFactory: PoolViewModelFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           networkFacade: WalletNetworkOperationFactoryProtocol?,
                           accountId: String,
                           address: String,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           referralFactory: ReferralsOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?) -> AssetDetailsViewController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let aseetList = assetManager.getAssetList() else { return nil }

        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: aseetList)

        let viewModelFactory = ActivityViewModelFactory(walletAssets: aseetList, assetManager: assetManager)
        let viewModel = AssetDetailsViewModel(wireframe: AssetDetailsWireframe(),
                                              assetInfo: assetInfo,
                                              assetViewModelFactory: assetViewModelFactory,
                                              assetManager: assetManager,
                                              historyService: historyService,
                                              fiatService: fiatService,
                                              viewModelFactory: viewModelFactory,
                                              eventCenter: EventCenter.shared,
                                              poolsService: poolsService,
                                              poolViewModelsFactory: poolViewModelsFactory,
                                              networkFacade: networkFacade,
                                              providerFactory: providerFactory,
                                              accountId: accountId,
                                              address: address,
                                              polkaswapNetworkFacade: polkaswapNetworkFacade,
                                              qrEncoder: qrEncoder,
                                              sharingFactory: sharingFactory,
                                              referralFactory: referralFactory,
                                              assetsProvider: assetsProvider)

        let view = AssetDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



