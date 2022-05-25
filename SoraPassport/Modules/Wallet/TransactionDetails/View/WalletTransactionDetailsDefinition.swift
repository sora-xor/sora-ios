import Foundation
import CommonWallet

protocol WalletTransactionDetailsDefining: WalletSoraFormDefining {
    func defineViewForAccountViewModel(_ viewModel: WalletAccountViewModel) -> WalletFormItemView?
    func defineViewForTransactionsViewModel(_ viewModel: WalletTransactionsViewModel) -> WalletFormItemView?
    func defineViewForHeader(_ viewModel: SoraTransactionHeaderViewModel) -> WalletFormItemView?
    func defineViewForStatus(_ viewModel: SoraTransactionStatusViewModel) -> WalletFormItemView?
    func defineViewForSoraReceiverViewModel(_ model: WalletSoraReceiverViewModel) -> WalletFormItemView?
    func defineViewForFeeViewModel(_ model: FeeViewModelProtocol) -> WalletFormItemView?
    func defineViewForAmountModel(_ model: SoraTransactionAmountViewModel) -> WalletFormItemView?
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
    func defineViewForAddLiquidityViewModel(_ model: AddLiquidityViewModel) -> WalletFormItemView? {
        return nil
    }
    
   
    func defineViewForSwapConfirmationHeaderViewModel(_ model: SoraSwapHeaderViewModel) -> WalletFormItemView? {
        return nil
    }

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

    func defineViewForHeader(_ viewModel: SoraTransactionHeaderViewModel) -> WalletFormItemView? {
        let view = R.nib.transactionDetailsHeaderView.firstView(owner: nil)!

        view.bind(viewModel: viewModel)

        return view
    }

    func  defineViewForSoraTokenViewModel(_ viewModel: WalletTokenViewModel) -> WalletFormItemView? {
        let view = R.nib.transactionDetailsHeaderView.firstView(owner: nil)!

        view.bind(viewModel: viewModel)

        return view
    }

    func defineViewForStatus(_ viewModel: SoraTransactionStatusViewModel) -> WalletFormItemView? {
        let view = R.nib.transactionDetailsStatusView.firstView(owner: nil)!

        view.bind(viewModel: viewModel)

        return view
    }

    func defineViewForSoraReceiverViewModel(_ model: WalletSoraReceiverViewModel) -> WalletFormItemView? {
        let view = R.nib.soraDetailsCopyView.firstView(owner: nil)!
        view.bind(viewModel: model)
        return view
    }

    func defineViewForAmountModel(_ model: SoraTransactionAmountViewModel) -> WalletFormItemView? {
        let view = R.nib.soraAmountInputView.firstView(owner: nil)!

        view.bind(viewModel: model)

        return view
    }

    func defineViewForFeeViewModel(_ model: FeeViewModelProtocol) -> WalletFormItemView? {
        let view = R.nib.soraFeeView.firstView(owner: nil)!

        view.bind(viewModel: model)

        return view
    }
    
}

struct WalletTxDetailsDefinitionFactory: WalletFormDefinitionFactoryProtocol {
    func createDefinitionWithBinder(_ binder: WalletFormViewModelBinderProtocol,
                                    itemFactory: WalletFormItemViewFactoryProtocol) -> WalletFormDefining {
        return WalletTransactionDetailsDefinition(binder: binder,
                                                  itemViewFactory: itemFactory)
    }
}
