import UIKit

final class SecurityLayerPresenter {
    weak var interactor: SecurityLayerInteractorInputProtocol?
    var wireframe: SecurityLayerWireframProtocol!
}

extension SecurityLayerPresenter: SecurityLayerInteractorOutputProtocol {
    func didDecideSecurePresentation() {
        wireframe.showSecuringOverlay()
    }

    func didDecideUnsecurePresentation() {
        wireframe.hideSecuringOverlay()
    }

    func didDecideRequestAuthorization() {
        wireframe.showAuthorization()
    }
}
