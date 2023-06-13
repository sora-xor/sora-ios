import Foundation
import IrohaCrypto
import SoraKeystore
import SCard
import SoraFoundation
import SoraUIKit

final class AccountExportWireframe: AccountExportWireframeProtocol, AuthorizationPresentable {

    private(set) var localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func showJson(from view: AccountExportViewProtocol?, account: AccountItem) {
        let warning = AccountWarningViewController(warningType: .json)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { [weak self] (isAuthorized) in
                if isAuthorized {
                    guard let accountExportView = self?.createAccountExportView(account) else {
                        return
                    }

                    var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    view?.controller.navigationController?.viewControllers = navigationArray
                    view?.controller.navigationController?.pushViewController(accountExportView.controller, animated: true)
                }
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    private func createAccountExportView(_ account: AccountItem) -> AccountExportViewProtocol? {
        let view = AccountExportViewController()

        let presenter = AccountExportPresenter()

        let interactor = AccountExportInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            account: account
        )
        let wireframe = AccountExportWireframe(localizationManager: self.localizationManager)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager

        return view
    }

    func showShareFile(url: NSURL, in viewController: AccountExportViewProtocol?) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        activityViewController.completionWithItemsHandler = { (_, completed: Bool, _, _) in
            if completed {
                viewController?.controller.navigationController?.popViewController(animated: true)
            }
        }

        viewController?.controller.present(activityViewController, animated: true)
    }
}
