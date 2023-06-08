import Foundation
import IrohaCrypto
import SoraKeystore
import RobinHood
import SoraFoundation

final class AccountExportViewFactory: AccountExportViewFactoryProtocol {
    static func createView(account: AccountItem) -> AccountExportViewProtocol? {
        let view = AccountExportViewController()
        let presenter = AccountExportPresenter()
        let interactor = AccountExportInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            account: account
        )

        let wireframe = AccountExportWireframe(localizationManager: LocalizationManager.shared)

        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
