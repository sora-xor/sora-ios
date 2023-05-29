import Foundation
import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol ConfirmWireframeProtocol: AlertPresentable {
    func showActivityIndicator()
    
    func hideActivityIndicator()
    
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?)
}

final class ConfirmWireframe {
    var activityIndicatorWindow: UIWindow?
}

extension ConfirmWireframe: ConfirmWireframeProtocol {    
    func showActivityIndicator() {
        activityIndicatorWindow = UIWindow(frame: UIScreen.main.bounds)
        activityIndicatorWindow?.windowLevel = UIWindow.Level.alert
        activityIndicatorWindow?.rootViewController = ActivityIndicatorViewController()
        activityIndicatorWindow?.isHidden = false
        activityIndicatorWindow?.makeKeyAndVisible()
    }
    
    func hideActivityIndicator() {
        activityIndicatorWindow?.isHidden = true
        activityIndicatorWindow = nil
    }
    
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?) {
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
        viewModel.completion = completion

        let assetDetailsController = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = assetDetailsController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.completionHandler = completion
        containerView.add(assetDetailsController)
        
        controller?.present(containerView, animated: true)
    }
}
