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
    
    func proceed(on controller: UIViewController?) {
        if endAddingBlock != nil {
            endAddingBlock?()
            return
        }
        
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        controller?.present(containerView, animated: true)
    }
}
