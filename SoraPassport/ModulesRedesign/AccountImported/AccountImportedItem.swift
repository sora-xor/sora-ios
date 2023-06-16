import SoraUIKit

final class AccountImportedItem: NSObject {

    let accountName: String?
    let accountAddress: String
    let areThereAnotherAccounts: Bool
    var continueTapHandler: (() -> Void)? = nil
    var loadMoreTapHandler: (() -> Void)? = nil

    init(accountName: String? = nil, accountAddress: String, areThereAnotherAccounts: Bool) {
        self.accountName = accountName
        self.accountAddress = accountAddress
        self.areThereAnotherAccounts = areThereAnotherAccounts
    }
}

extension AccountImportedItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        AccountImportedCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
}
