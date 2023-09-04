import Foundation
import UIKit

final class AccountExportPresenter {
    weak var view: AccountExportViewProtocol?
    var wireframe: AccountExportWireframeProtocol!
    var interactor: AccountExportInteractorInputProtocol!
    private var appEventService = AppEventService()
}

extension AccountExportPresenter: AccountExportPresenterProtocol {

    func exportWith(password: String) {
        guard let url = interactor.exportToFileWith(password: password) else {
            return
        }
        wireframe.showShareFile(url: url, in: view)
    }
}

extension AccountExportPresenter: AccountExportInteractorOutputProtocol {}
