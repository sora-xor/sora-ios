import Foundation
import UIKit
import SoraUIKit
import CommonWallet

protocol GenerateQRWireframeProtocol: AnyObject {
    func showAssetSelection(
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        assetViewModelFactory: AssetViewModelFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        assetIds: [String],
        completion: @escaping (String) -> Void
    )
    
    func showReceive(selectedAsset: AssetInfo,
                     accountId: String,
                     address: String,
                     amount: AmountDecimal?,
                     qrEncoder: WalletQREncoderProtocol,
                     sharingFactory: AccountShareFactoryProtocol,
                     fiatService: FiatServiceProtocol?,
                     assetProvider: AssetProviderProtocol?,
                     assetManager: AssetManagerProtocol?)
    
    func showScanQR(on view: UIViewController,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    scanCompletion: @escaping (ScanQRResult) -> Void)
    
    func showConfirmSendingAsset(on controller: UIViewController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?)
    
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol)
}

final class GenerateQRWireframe: GenerateQRWireframeProtocol {
    
    weak var controller: UIViewController?
    
    init(controller: UIViewController?) {
        self.controller = controller
    }
    
    func showAssetSelection(
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        assetViewModelFactory: AssetViewModelFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        assetIds: [String],
        completion: @escaping (String) -> Void
    ) {
        let viewModel = SelectAssetViewModel(assetViewModelFactory: assetViewModelFactory,
                                             fiatService: fiatService,
                                             assetManager: assetManager,
                                             assetsProvider: assetsProvider,
                                             assetIds: assetIds)
        viewModel.selectionCompletion = completion

        let assetListController = ProductListViewController(viewModel: viewModel)
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: assetListController)
        navigationController.navigationBar.backgroundColor = .clear
        
        containerView.add(navigationController)
        controller?.present(containerView, animated: true)
    }
    
    func showReceive(selectedAsset: AssetInfo,
                     accountId: String,
                     address: String,
                     amount: AmountDecimal?,
                     qrEncoder: WalletQREncoderProtocol,
                     sharingFactory: AccountShareFactoryProtocol,
                     fiatService: FiatServiceProtocol?,
                     assetProvider: AssetProviderProtocol?,
                     assetManager: AssetManagerProtocol?) {
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)
        
        let viewModel = ReceiveViewModel(qrService: qrService,
                                         sharingFactory: sharingFactory,
                                         accountId: accountId,
                                         address: address,
                                         selectedAsset: selectedAsset,
                                         amount: amount,
                                         fiatService: fiatService,
                                         assetProvider: assetProvider,
                                         assetManager: assetManager)
        let receiveController = ReceiveViewController(viewModel: viewModel)
        viewModel.view = receiveController
        
        controller?.navigationController?.pushViewController(receiveController, animated: true)
    }
    
    func showScanQR(on view: UIViewController,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    scanCompletion: @escaping (ScanQRResult) -> Void) {
        guard let currentUser = SelectedWalletSettings.shared.currentAccount else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let scanView = ScanQRViewFactory.createView(assetManager: assetManager,
                                                    currentUser: currentUser,
                                                    networkFacade: networkFacade,
                                                    qrEncoder: qrEncoder,
                                                    sharingFactory: sharingFactory,
                                                    assetsProvider: assetsProvider,
                                                    isGeneratedQRCodeScreenShown: true,
                                                    providerFactory: providerFactory,
                                                    feeProvider: feeProvider,
                                                    completion: scanCompletion)
        containerView.add(scanView.controller)
        view.present(containerView, animated: true)
    }
    
    func showConfirmSendingAsset(on controller: UIViewController?,
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
        
        let navigationController = UINavigationController(rootViewController: view)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol) {
        let viewModel = InputAssetAmountViewModel(selectedTokenId: selectedTokenId,
                                                  selectedAddress: selectedAddress,
                                                  fiatService: fiatService,
                                                  assetManager: assetManager,
                                                  providerFactory: providerFactory,
                                                  networkFacade: networkFacade,
                                                  wireframe: InputAssetAmountWireframe(),
                                                  assetsProvider: assetsProvider,
                                                  qrEncoder: qrEncoder,
                                                  sharingFactory: sharingFactory)
        let inputAmountController = InputAssetAmountViewController(viewModel: viewModel)
        viewModel.view = inputAmountController
        
        let navigationController = UINavigationController(rootViewController: inputAmountController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
}
