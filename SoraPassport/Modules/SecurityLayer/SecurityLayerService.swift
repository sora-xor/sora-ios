import Foundation
import SoraKeystore
import SoraFoundation

final class SecurityLayerService {
    static let pincodeTimeoutInMinutes = 5.0
    static let secondsInMinutes = 60.0
    static let pincodeDelayInSeconds: TimeInterval = pincodeTimeoutInMinutes * secondsInMinutes

    static let sharedInteractor: SecurityLayerInteractorInputProtocol = {
        let presenter = SecurityLayerPresenter()
        let interactor = SecurityLayerInteractor(applicationHandler: ApplicationHandler(),
                                                 settings: SettingsManager.shared,
                                                 keystore: Keychain(),
                                                 pincodeDelay: pincodeDelayInSeconds)
        let wireframe = SecurityLayerWireframe()

        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return interactor
    }()
}
