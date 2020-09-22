import Foundation
import CommonWallet

protocol WalletTransactionDetailsDefining: WalletFormDefining {
    func defineViewForAccountViewModel(_ viewModel: WalletAccountViewModel) -> WalletFormItemView?
    func defineViewForTransactionsViewModel(_ viewModel: WalletTransactionsViewModel) -> WalletFormItemView?
}

final class WalletTransactionDetailsDefinition {
    let binder: WalletFormViewModelBinderProtocol
    let itemViewFactory: WalletFormItemViewFactoryProtocol

    init(binder: WalletFormViewModelBinderProtocol,
         itemViewFactory: WalletFormItemViewFactoryProtocol) {
        self.binder = binder
        self.itemViewFactory = itemViewFactory
    }
}

extension WalletTransactionDetailsDefinition: WalletTransactionDetailsDefining {
    func defineViewForAccountViewModel(_ viewModel: WalletAccountViewModel) -> WalletFormItemView? {
        guard let accountView = R.nib.walletAccountView(owner: nil) else {
            return nil
        }

        accountView.bind(viewModel: viewModel)
        return accountView
    }

    func defineViewForTransactionsViewModel(_ viewModel: WalletTransactionsViewModel) -> WalletFormItemView? {
        guard let transactionsView = R.nib.walletTransactionsView(owner: nil) else {
            return nil
        }

        transactionsView.bind(viewModel: viewModel)
        return transactionsView
    }
}

struct WalletTxDetailsDefinitionFactory: WalletFormDefinitionFactoryProtocol {
    func createDefinitionWithBinder(_ binder: WalletFormViewModelBinderProtocol,
                                    itemFactory: WalletFormItemViewFactoryProtocol) -> WalletFormDefining {
        return WalletTransactionDetailsDefinition(binder: binder,
                                                  itemViewFactory: itemFactory)
    }
}
