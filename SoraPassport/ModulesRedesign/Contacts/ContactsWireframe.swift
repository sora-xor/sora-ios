import Foundation
import SoraUIKit
import RobinHood
import CommonWallet
import SoraFoundation

protocol ContactsWireframeProtocol {    
    func showScanQR(on view: UIViewController?,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    completion: ((ScanQRResult) -> Void)?)
}

final class ContactsWireframe: ContactsWireframeProtocol {
    func showScanQR(on view: UIViewController?,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    completion: ((ScanQRResult) -> Void)?) {
        guard let currentUser = SelectedWalletSettings.shared.currentAccount else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let scanView = ScanQRViewFactory.createView(assetManager: assetManager,
                                                    currentUser: currentUser,
                                                    networkFacade: networkFacade,
                                                    qrEncoder: qrEncoder,
                                                    sharingFactory: sharingFactory,
                                                    assetsProvider: assetsProvider,
                                                    providerFactory: providerFactory,
                                                    feeProvider: feeProvider,
                                                    completion: completion)
        containerView.add(scanView.controller)
        view?.present(containerView, animated: true)
    }
}
