import Foundation
import UIKit
import RobinHood
import CommonWallet
import SoraUIKit

protocol InputAssetAmountWireframeProtocol: AlertPresentable {
    func showChoiceBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactoryProtocol,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             completion: @escaping (String) -> Void)
    
    func showSelectAddress(on controller: UIViewController?,
                           assetId: String,
                           dataProvider: SingleValueProvider<[SearchData]>,
                           walletService: WalletServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           completion: ((ScanQRResult) -> Void)?)
    
    func showConfirmSendingAsset(on controller: UINavigationController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?)
}

final class InputAssetAmountWireframe: InputAssetAmountWireframeProtocol {

    func showChoiceBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactoryProtocol,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             completion: @escaping (String) -> Void) {
        let viewModel = SelectAssetViewModel(assetViewModelFactory: assetViewModelFactory,
                                             fiatService: fiatService,
                                             assetManager: assetManager,
                                             assetsProvider: assetsProvider,
                                             assetIds: assetIds)
        viewModel.selectionCompletion = completion

        let assetListController = ProductListViewController(viewModel: viewModel)
        
        let navigationController = UINavigationController(rootViewController: assetListController)
        
        controller?.present(navigationController, animated: true)
    }
    
    func showSelectAddress(on controller: UIViewController?,
                           assetId: String,
                           dataProvider: SingleValueProvider<[SearchData]>,
                           walletService: WalletServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           completion: ((ScanQRResult) -> Void)?) {
        guard let currentUser = SelectedWalletSettings.shared.currentAccount else { return }
        let viewModelFactory = ContactsViewModelFactory(dataStorageFacade: SubstrateDataStorageFacade.shared)
        let localSearchEngine = ContactsLocalSearchEngine(networkType: currentUser.networkType, contactViewModelFactory: viewModelFactory)
        
        let settingsManager = SelectedWalletSettings.shared
        
        let viewModel = ContactsViewModel(dataProvider: dataProvider,
                                          walletService: walletService,
                                          assetId: assetId,
                                          localSearchEngine: localSearchEngine,
                                          wireframe: ContactsWireframe(),
                                          networkFacade: networkFacade,
                                          assetManager: assetManager,
                                          settingsManager: settingsManager,
                                          qrEncoder: qrEncoder,
                                          sharingFactory: sharingFactory,
                                          assetsProvider: assetsProvider)
        viewModel.completion = completion
        let receiveController = ContactsViewController(viewModel: viewModel)
        viewModel.view = receiveController
        
        let navigationController = UINavigationController(rootViewController: receiveController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showConfirmSendingAsset(on controller: UINavigationController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?) {
        let viewModel = ConfirmSendingViewModel(wireframe: ConfirmWireframe(),
                                                fiatService: fiatService,
                                                assetManager: assetManager,
                                                detailsFactory: DetailViewModelFactory(assetManager: assetManager),
                                                assetId: assetId,
                                                recipientAddress: recipientAddress,
                                                firstAssetAmount: firstAssetAmount,
                                                transactionType: .outgoing,
                                                fee: fee,
                                                walletService: walletService,
                                                assetsProvider: assetsProvider)
        let view = ConfirmViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
}
