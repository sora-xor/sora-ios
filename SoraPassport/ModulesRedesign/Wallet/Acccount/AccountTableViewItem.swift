import Foundation
import SoraUIKit
import RobinHood

final class AccountTableViewItem: NSObject {

    var accountName: String
    var accountHandler: ((AccountTableViewItem) -> Void)?
    var scanQRHandler: (() -> Void)?
    var updateHandler: (() -> Void)?
    private let accountRepository: AnyDataProviderRepository<AccountItem>

    init(accountName: String) {
        self.accountName = accountName
        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )
        super.init()
        EventCenter.shared.add(observer: self)
    }
}

extension AccountTableViewItem: EventVisitorProtocol {
    func processSelectedUsernameChanged(event: SelectedUsernameChanged) {
        
        let persistentOperation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            
            let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
            let selectedAccount =  accounts.first { $0.address == selectedAccountAddress }
            var selectedAccountName = selectedAccount?.username ?? ""
            
            if selectedAccountName.isEmpty {
                selectedAccountName = selectedAccount?.address ?? ""
            }
            self?.accountName = selectedAccountName
            self?.updateHandler?()
        }

        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }
}


extension AccountTableViewItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AccountCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
    
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        40
    }
}
