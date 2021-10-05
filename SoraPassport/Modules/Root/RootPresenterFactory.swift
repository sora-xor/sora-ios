import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: SoraWindow) -> RootPresenterProtocol {

        AppearanceFactory.applyGlobalAppearance()

        let presenter = RootPresenter()
        let wireframe = RootWireframe()

        NetworkAvailabilityLayerService.shared.setup(with: view,
                                                     localizationManager: LocalizationManager.shared,
                                                     logger: Logger.shared)
        let networkAvailabilityInteractor = NetworkAvailabilityLayerService.shared.interactor

        let interactor = RootInteractor(settings: SettingsManager.shared,
                                        keystore: Keychain(),
                                        securityLayerInteractor: SecurityLayerService.sharedInteractor,
                                        networkAvailabilityLayerInteractor: networkAvailabilityInteractor)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
