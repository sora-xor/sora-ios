import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

final class ChangeAccountViewFactory: ChangeAccountViewFactoryProtocol {
    static func changeAccountViewController(with completion: @escaping () -> Void) -> ChangeAccountViewProtocol? {
        let view = ChangeAccountViewController(nib: R.nib.changeAccountViewController)
        
        let accountViewModelFactory = AccountViewModelFactory()
        let settingsManager = SelectedWalletSettings.shared
        let presenter = ChangeAccountPresenter(accountViewModelFactory: accountViewModelFactory,
                                               settingsManager: settingsManager,
                                               eventCenter: EventCenter.shared)
        
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository(filter: nil,
                                                              sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        
        let operationManager = OperationManagerFacade.sharedManager
        
        let interactor = ChangeAccountInteractor(accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: operationManager)
        let wireframe = ChangeAccountWireframe()

        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        presenter.endUpdatingBlock = completion
        interactor.presenter = presenter

        return view
    }
}
