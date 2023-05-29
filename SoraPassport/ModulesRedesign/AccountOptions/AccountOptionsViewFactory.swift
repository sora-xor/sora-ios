import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class AccountOptionsViewFactory: AccountOptionsViewFactoryProtocol {
    static func createView(account: AccountItem) -> AccountOptionsViewProtocol? {

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()
        let chain = ChainRegistryFacade.sharedRegistry.getChain(for: Chain.sora.genesisHash())!

        let view = AccountOptionsViewController()
        let presenter = AccountOptionsPresenter()
        let interactor = AccountOptionsInteractor(keystore: Keychain(),
                                                  settings: SettingsManager.shared,
                                                  chain: chain,
                                                  cacheFacade: CacheFacade.shared,
                                                  substrateDataFacade: SubstrateDataStorageFacade.shared,
                                                  userDataFacade: UserDataStorageFacade.shared,
                                                  account: account,
                                                  accountRepository: AnyDataProviderRepository(accountRepository),
                                                  operationManager: OperationManagerFacade.sharedManager,
                                                  eventCenter: EventCenter.shared)
        let wireframe = AccountOptionsWireframe(localizationManager: LocalizationManager.shared)
        
        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
