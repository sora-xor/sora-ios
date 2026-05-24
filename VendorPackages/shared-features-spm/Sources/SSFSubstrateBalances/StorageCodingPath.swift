import Foundation
import SSFModels

public enum StorageCodingPath: Equatable, CaseIterable, StorageCodingPathProtocol {
    public var moduleName: String {
        path.moduleName
    }

    public var itemName: String {
        path.itemName
    }

    public var path: (moduleName: String, itemName: String) {
        switch self {
        case .tokensAccounts:
            return (moduleName: "Tokens", itemName: "Accounts")
        case .systemAccount:
            return (moduleName: "System", itemName: "Account")
        }
    }

    case tokensAccounts
    case systemAccount
}
