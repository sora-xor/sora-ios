import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

final class ChangeAccountViewFactory: ChangeAccountViewFactoryProtocol {
    static func changeAccountViewController(with completion: @escaping () -> Void) -> ChangeAccountViewProtocol? {
        let view = ChangeAccountViewController()
        
        let settingsManager = SelectedWalletSettings.shared
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository(filter: nil,
                                                              sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        
        let operationManager = OperationManagerFacade.sharedManager


        let presenter = ChangeAccountPresenter(settingsManager: settingsManager,
                                               eventCenter: EventCenter.shared,
                                               accountRepository: AnyDataProviderRepository(accountRepository),
                                               operationManager: operationManager,
                                               serviceCoordinator: ServiceCoordinator.shared)
        
        
        let wireframe = ChangeAccountWireframe()

        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.endUpdatingBlock = completion

        return view
    }
}
