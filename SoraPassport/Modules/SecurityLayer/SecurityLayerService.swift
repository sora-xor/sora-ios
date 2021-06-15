import Foundation
import SoraKeystore
import SoraFoundation

final class SecurityLayerService {
    static let pincodeDelay: TimeInterval = 1.0 * 60.0

    static let sharedInteractor: SecurityLayerInteractorInputProtocol = {
        let presenter = SecurityLayerPresenter()
        let interactor = SecurityLayerInteractor(applicationHandler: ApplicationHandler(),
                                                 settings: SettingsManager.shared,
                                                 keystore: Keychain(),
                                                 pincodeDelay: pincodeDelay)
        let wireframe = SecurityLayerWireframe()

        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return interactor
    }()
}
