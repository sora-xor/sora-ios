import Foundation
import UIKit

final class AccountExportRawSeedPresenter {
    weak var view: AccountExportRawSeedViewProtocol?
    var wireframe: AccountExportRawSeedWireframeProtocol!
    var interactor: AccountExportRawSeedInteractorInputProtocol!
    private var appEventService = AppEventService()
}

extension AccountExportRawSeedPresenter: AccountExportRawSeedPresenterProtocol {
    func copyRawSeed() {
        interactor.copyRawSeedToClipboard()
    }

    func exportRawSeed() {
        interactor.exportRawSeed()
    }
}

extension AccountExportRawSeedPresenter: AccountExportRawSeedInteractorOutputProtocol {
    func set(rawSeed: String) {
        view?.set(rawSeed: rawSeed)
    }
}
