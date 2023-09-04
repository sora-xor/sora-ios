import Foundation
import IrohaCrypto
import SoraKeystore
import RobinHood
import SoraFoundation

final class AccountExportRawSeedViewFactory: AccountExportRawSeedViewFactoryProtocol {
    static func createView(account: AccountItem) -> AccountExportRawSeedViewProtocol? {
        let view = AccountExportRawSeedViewController()
        let presenter = AccountExportRawSeedPresenter()
        let interactor = AccountExportRawSeedInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            account: account
        )

        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        return view
    }
}
