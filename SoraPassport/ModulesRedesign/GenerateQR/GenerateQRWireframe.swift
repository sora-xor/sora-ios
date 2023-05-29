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
        
        let navigationController = UINavigationController(rootViewController: assetListController)
        
        controller?.present(navigationController, animated: true)
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
}
