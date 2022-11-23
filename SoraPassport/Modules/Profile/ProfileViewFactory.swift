import UIKit
import RobinHood
import SoraKeystore
import SoraFoundation
import CommonWallet

final class ProfileViewFactory: ProfileViewFactoryProtocol {
	static func createView(walletContext: CommonWalletContextProtocol) -> ProfileViewProtocol? {

        let profileViewModelFactory = ProfileViewModelFactory()

        let presenter = ProfilePresenter(
            viewModelFactory: profileViewModelFactory,
            settingsManager: SettingsManager.shared
        )

        presenter.localizationManager = LocalizationManager.shared

        let view = ProfileViewController(nib: R.nib.profileViewController)
        view.definesPresentationContext = true
        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter

        presenter.view = view

        let wireframe = ProfileWireframe(
            settingsManager: SettingsManager.shared,
            localizationManager: LocalizationManager.shared,
            disclaimerViewFactory: DisclaimerViewFactory(),
            walletContext: walletContext
        )

        presenter.wireframe = wireframe

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()
        let chain = ChainRegistryFacade.sharedRegistry.getChain(for: Chain.sora.genesisHash())!

        let interactor = ProfileInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            chain: chain,
            cacheFacade: CacheFacade.shared,
            substrateDataFacade: SubstrateDataStorageFacade.shared,
            userDataFacade: UserDataStorageFacade.shared,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )

        interactor.presenter = presenter
        presenter.interactor = interactor

        return view
	}
}
