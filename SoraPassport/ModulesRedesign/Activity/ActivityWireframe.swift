import Foundation
import UIKit
import SoraUIKit

protocol ActivityWireframeProtocol {
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol)
}

final class ActivityWireframe: ActivityWireframeProtocol {

    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol) {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount, let aseetList = assetManager.getAssetList() else { return }

        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: aseetList)
        
        let factory = ActivityDetailsViewModelFactory(assetManager: assetManager)
        let viewModel = ActivityDetailsViewModel(model: model,
                                                 wireframe: ActivityDetailsWireframe(),
                                                 assetManager: assetManager,
                                                 detailsFactory: factory,
                                                 historyService: historyService,
                                                 lpServiceFee: LPFeeService())

        let assetDetailsController = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = assetDetailsController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(assetDetailsController)
        
        controller?.present(containerView, animated: true)
    }
}
