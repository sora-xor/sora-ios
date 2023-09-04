import Foundation
import UIKit

protocol AccountExportRawSeedViewProtocol: ControllerBackedProtocol {
    func set(rawSeed: String)
}

protocol AccountExportRawSeedPresenterProtocol: AnyObject {
    func exportRawSeed()
    func copyRawSeed()
}

protocol AccountExportRawSeedInteractorInputProtocol: AnyObject {
    func exportRawSeed()
    func copyRawSeedToClipboard()
}

protocol AccountExportRawSeedInteractorOutputProtocol: AnyObject {
    func set(rawSeed: String)
}

protocol AccountExportRawSeedWireframeProtocol: AnyObject {
}

protocol AccountExportRawSeedViewFactoryProtocol: AnyObject {
    static func createView(account: AccountItem) -> AccountExportRawSeedViewProtocol?
}
