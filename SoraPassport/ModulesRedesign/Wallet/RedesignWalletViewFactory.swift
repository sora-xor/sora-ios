import Foundation
import RobinHood
import CommonWallet

protocol RedesignWalletViewFactoryProtocol: AnyObject {
    static func createView(providerFactory: BalanceProviderFactory,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           accountId: String,
                           address: String,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           referralFactory: ReferralsOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol,
                           walletContext: CommonWalletContextProtocol) -> RedesignWalletViewController
}

final class RedesignWalletViewFactory: RedesignWalletViewFactoryProtocol {
    static func createView(providerFactory: BalanceProviderFactory,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           accountId: String,
                           address: String,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           referralFactory: ReferralsOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol,
                           walletContext: CommonWalletContextProtocol) -> RedesignWalletViewController {
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)
        
        let viewModel = RedesignWalletViewModel(wireframe: RedesignWalletWireframe(),
                                                providerFactory: providerFactory,
                                                assetManager: assetManager,
                                                fiatService: fiatService,
                                                itemFactory: WalletItemFactory(),
                                                networkFacade: networkFacade,
                                                accountId: accountId,
                                                address: address,
                                                polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                qrEncoder: qrEncoder,
                                                sharingFactory: sharingFactory,
                                                poolsService: poolsService,
                                                referralFactory: referralFactory,
                                                assetsProvider: assetsProvider,
                                                walletContext: walletContext,
                                                editViewService: editViewService)
        
        let view = RedesignWalletViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



