import Foundation
import UIKit
import SoraUIKit
import CommonWallet

protocol ScanQRWireframeProtocol {
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?)
}

final class ScanQRWireframe: ScanQRWireframeProtocol {

    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?) {
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)
       
        let viewModel = GenerateQRViewModel(
            qrService: qrService,
            sharingFactory: sharingFactory,
            accountId: accountId,
            address: address,
            fiatService: FiatService.shared,
            assetManager: assetManager,
            assetsProvider: assetsProvider,
            qrEncoder: qrEncoder
        )
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
