import Foundation
import SoraFoundation

final class NetworkAvailabilityLayerService {
    static let shared = NetworkAvailabilityLayerService()

    private(set) var interactor: NetworkAvailabilityLayerInteractorInputProtocol?

    func setup(with view: SoraWindow,
               localizationManager: LocalizationManagerProtocol,
               logger: LoggerProtocol? = nil) {
        guard let reachabilityManager = ReachabilityManager.shared else {
            return
        }

        let presenter = NetworkAvailabilityLayerPresenter()
        let interactor = NetworkAvailabilityLayerInteractor(reachabilityManager: reachabilityManager)
        interactor.logger = logger

        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        self.interactor = interactor

        presenter.localizationManager = localizationManager
    }
}
