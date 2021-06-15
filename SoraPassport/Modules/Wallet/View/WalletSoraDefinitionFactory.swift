import Foundation
import CommonWallet

struct WalletSoraDefinitionFactory: WalletFormDefinitionFactoryProtocol {
    func createDefinitionWithBinder(
        _ binder: WalletFormViewModelBinderProtocol,
        itemFactory: WalletFormItemViewFactoryProtocol
    ) -> WalletFormDefining {
        WalletSoraDefinition(binder: binder, itemViewFactory: itemFactory)
    }
}
