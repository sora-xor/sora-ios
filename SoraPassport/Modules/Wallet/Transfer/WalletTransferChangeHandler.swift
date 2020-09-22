import Foundation
import CommonWallet

struct WalletTransferChangeHandler: OperationDefinitionChangeHandling {
    func updateContentForChange(event: OperationDefinitionChangeEvent) -> [OperationDefinitionType] {
        switch event {
        case .asset:
            return [.asset, .amount, .fee]
        case .balance:
            return [.asset]
        case .amount:
            return [.asset, .fee]
        case .metadata:
            return [.asset, .fee]
        }
    }

    func clearErrorForChange(event: OperationDefinitionChangeEvent) -> [OperationDefinitionType] {
        switch event {
        case .asset:
            return [.asset, .amount, .fee]
        case .balance:
            return [.asset, .amount, .fee]
        case .amount:
            return [.amount, .fee]
        case .metadata:
            return [.amount, .fee]
        }
    }

    func shouldUpdateAccessoryForChange(event: OperationDefinitionChangeEvent) -> Bool {
        false
    }
}
