import Foundation
import SoraFoundation
import SoraKeystore
import CommonWallet

final class FriendsViewFactory: FriendsViewFactoryProtocol {
    static func createView(walletContext: CommonWalletContextProtocol) -> FriendsViewProtocol? {
        let settings = SettingsManager.shared
        let keychain = Keychain()

        let chainId = Chain.sora.genesisHash()
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: chainId)
        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
              let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let feeAsset = assetManager.getAssetList()?.first(where: { $0.isFeeAsset })  else { return nil }

        let view = FriendsViewController(nib: R.nib.friendsViewController)
        view.localizationManager = LocalizationManager.shared

        let presenter = FriendsPresenter(settings: settings,
                                         keychain: keychain,
                                         selectedAccount: selectedAccount,
                                         feeAsset: feeAsset)
        presenter.localizationManager = LocalizationManager.shared

        let operationFactory = ReferralsOperationFactory(settings: settings,
                                                         keychain: keychain,
                                                         engine: engine, runtimeRegistry: runtimeRegistry,
                                                         selectedAccount: selectedAccount)

        let interactor = FriendsInteractor(engine: engine,
                                           address: selectedAccount.address,
                                           config: ApplicationConfig.shared,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           keychain: keychain,
                                           operationFactory: operationFactory)

        let wireframe = FriendsWireframe(walletContext: walletContext)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
