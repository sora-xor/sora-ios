import UIKit
import RobinHood
import SoraKeystore
import SoraFoundation
import CommonWallet

final class MoreMenuViewFactory {
    static func createView(
        walletContext: CommonWalletContextProtocol,
        fiatService: FiatServiceProtocol,
        balanceFactory: BalanceProviderFactory,
        address: AccountAddress,
        assetsProvider: AssetProviderProtocol
    ) -> MoreMenuViewProtocol? {

        let view = MoreMenuViewController()
        let presenter = MoreMenuPresenter()
        let wireframe = MoreMenuWireframe(
            settingsManager: SettingsManager.shared,
            localizationManager: LocalizationManager.shared,
            walletContext: walletContext,
            fiatService: fiatService,
            balanceFactory: balanceFactory,
            address: address,
            assetsProvider: assetsProvider
        )
        presenter.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
