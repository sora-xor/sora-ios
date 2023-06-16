import Foundation
import UIKit
import SoraUIKit
import CommonWallet

protocol ScanQRWireframeProtocol {
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        closeHandler: (() -> Void)?)
}

final class ScanQRWireframe: ScanQRWireframeProtocol {

    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        closeHandler: (() -> Void)?) {
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)
       
        let viewModel = GenerateQRViewModel(
            qrService: qrService,
            sharingFactory: sharingFactory,
            accountId: accountId,
            address: address,
            username: username,
            fiatService: FiatService.shared,
            assetManager: assetManager,
            assetsProvider: assetsProvider,
            qrEncoder: qrEncoder
        )
        viewModel.closeHadler = closeHandler
        let viewController = GenerateQRViewController(viewModel: viewModel)
        viewModel.view = viewController
        viewModel.wireframe = GenerateQRWireframe(controller: viewController)

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
}
