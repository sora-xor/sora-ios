import Foundation
import SoraKeystore
import SoraFoundation
import SoraUIKit

final class SetupPasswordWireframe {
    var activityIndicatorWindow: UIWindow?
    weak var currentController: SetupPasswordViewProtocol?

    init(currentController: SetupPasswordViewProtocol?) {
        self.currentController = currentController
    }
}

extension SetupPasswordWireframe: SetupPasswordWireframeProtocol {
    func showSetupPinCode() {
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        currentController?.controller.present(containerView, animated: true)
    }
}
