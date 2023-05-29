import UIKit
import SoraKeystore

final class SplashPresenter: SplashPresenterProtocol {
    weak var view: SplashViewProtocol?
    var interactor: SplashInteractorProtocol!
    var window: SoraWindow!
    var wireframe: SplashWireframe?

    init(window: SoraWindow) {
        self.window = window
    }

    func setupComplete() {
        DispatchQueue.main.async {
            self.view?.animate(duration: 2, completion: {
                self.wireframe?.showRoot(on: self.window)
            })
        }
    }
}

final class SplashWireframe {
    func showRoot(on view: SoraWindow) {
        let presenter = RootPresenterFactory.createPresenter(with: view)
        presenter.loadOnLaunch()
    }
}
