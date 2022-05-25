import Foundation
import CommonWallet

struct WalletAccountViewModel {
    enum AccountType {
        case soranet
        case ethereum
        case val
    }

    let title: String
    let type: AccountType
    let command: WalletCommandProtocol
}

extension WalletAccountViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let trasactionDetailsDefinition = definition as? WalletTransactionDetailsDefining {
            return trasactionDetailsDefinition.defineViewForAccountViewModel(self)
        } else {
            return nil
        }
    }
}
