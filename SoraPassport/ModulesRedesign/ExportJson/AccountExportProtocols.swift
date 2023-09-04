import Foundation
import UIKit

protocol AccountExportViewProtocol: ControllerBackedProtocol {
}

protocol AccountExportPresenterProtocol: AnyObject {
    func exportWith(password: String)
}

protocol AccountExportInteractorInputProtocol: AnyObject {
    func exportToFileWith(password: String) -> NSURL?
}

protocol AccountExportInteractorOutputProtocol: AnyObject {
}

protocol AccountExportWireframeProtocol: AnyObject {
    func showShareFile(url: NSURL, in viewController: AccountExportViewProtocol?)
}

protocol AccountExportViewFactoryProtocol: AnyObject {
    static func createView(accounts: [AccountItem]) -> AccountExportViewProtocol?
}
