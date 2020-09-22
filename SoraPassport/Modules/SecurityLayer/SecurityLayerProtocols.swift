import UIKit

protocol SecurityLayerInteractorInputProtocol: class {
    func setup()
}

protocol SecurityLayerInteractorOutputProtocol: class {
    func didDecideSecurePresentation()
    func didDecideUnsecurePresentation()
    func didDecideRequestAuthorization()
}

protocol SecurityLayerWireframProtocol: class {
    func showSecuringOverlay()
    func hideSecuringOverlay()
    func showAuthorization()
}
