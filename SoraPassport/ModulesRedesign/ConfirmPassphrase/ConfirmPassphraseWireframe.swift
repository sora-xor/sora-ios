import Foundation
import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol ConfirmPassphraseyWireframeProtocol: AlertPresentable {
    func proceed(on controller: UIViewController?)
}

final class ConfirmPassphraseyWireframe: ConfirmPassphraseyWireframeProtocol {
    var endAddingBlock: (() -> Void)?
    var isNeedSetupName: Bool = true
    
    func proceed(on controller: UIViewController?) {
        if endAddingBlock != nil {
            guard
                !isNeedSetupName,
                let setupNameView = SetupAccountNameViewFactory.createViewForImport(endAddingBlock: endAddingBlock)?.controller,
                let navigationController = controller?.navigationController?.topModalViewController.children.first as? UINavigationController
            else {
                controller?.navigationController?.dismiss(animated: true, completion: endAddingBlock)
                return
            }

            navigationController.setViewControllers([setupNameView], animated: true)
            return
        }
        
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        controller?.present(containerView, animated: true)
    }
}
