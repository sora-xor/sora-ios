import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class SetupNameImportAccountPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var viewModel: InputViewModel!
    var successEditingBlock: (() -> Void)?
    let settingsManager = SelectedWalletSettings.shared
    var mode: UsernameSetupMode = .onboarding
    var userName: String?
    
    var currentAccount: AccountItem
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let eventCenter: EventCenterProtocol
    private let operationManager: OperationManagerProtocol
    
    init(currentAccount: AccountItem,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol) {
        self.currentAccount = currentAccount
        self.accountRepository = accountRepository
        self.eventCenter = eventCenter
        self.operationManager = operationManager
    }
}

extension SetupNameImportAccountPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        let value = mode == .creating ? "" : userName ?? ""
        
        let inputHandling = InputHandler(value: value,
                                         required: false,
                                         predicate: NSPredicate.notEmpty,
                                         processor: ByteLengthProcessor.username)
        viewModel = InputViewModel(inputHandler: inputHandling)
        view?.set(viewModel: viewModel)
    }

    func proceed() {
        if let updated = settingsManager.currentAccount?.replacingUsername(userName ?? "") {
            settingsManager.save(value: updated)
            wireframe.showPinCode(from: view)
        }
    }
    
    func endEditing() {
        successEditingBlock?()
    }

    func activateURL(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url,
                              from: view,
                              style: .modal)
        }
    }
}
    
extension SetupNameImportAccountPresenter: Localizable {
    func applyLocalization() {}
}
