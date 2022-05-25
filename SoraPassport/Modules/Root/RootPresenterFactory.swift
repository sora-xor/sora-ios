import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: SoraWindow) -> RootPresenterProtocol {

        AppearanceFactory.applyGlobalAppearance()

        let presenter = RootPresenter()
        let wireframe = RootWireframe()
        let keychain = Keychain()
        let settings = SettingsManager.shared

        NetworkAvailabilityLayerService.shared.setup(with: view,
                                                     localizationManager: LocalizationManager.shared,
                                                     logger: Logger.shared)
        let networkAvailabilityInteractor = NetworkAvailabilityLayerService.shared.interactor
        let inconsistentStateMigrator = InconsistentStateMigrator(
            settings: settings,
            keychain: keychain
        )
        let interactor = RootInteractor(settings: settings,
                                        keystore: keychain,
                                        migrators: [inconsistentStateMigrator],
                                        securityLayerInteractor: SecurityLayerService.sharedInteractor,
                                        networkAvailabilityLayerInteractor: networkAvailabilityInteractor)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
