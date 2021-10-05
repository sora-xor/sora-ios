import Foundation
import SoraKeystore

protocol SplashPresenterProtocol: class {
    func setupComplete()
}

protocol SplashInteractorProtocol: class {
    func setup()
}

protocol SplashViewProtocol: class {
    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void)
}

final class SplashPresenterFactory {
    static func createSplashPresenter(with window: SoraWindow) {
        let presenter = SplashPresenter(window: window)
        let interactor = SplashInteractor(settings: SettingsManager.shared,
                                          operationManager: OperationManagerFacade.sharedManager,
                                          socketService: WebSocketService.shared,
                                          runtimeService: RuntimeRegistryFacade.sharedService)
        let wireframe = SplashWireframe()
        let view = SplashViewController()
        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        interactor.setup()
        window.rootViewController = view
    }
}
