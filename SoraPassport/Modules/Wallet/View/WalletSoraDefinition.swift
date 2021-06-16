/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

protocol WalletSoraFormDefining: WalletFormDefining {
    func defineViewForSoraTokenViewModel(_ model: WalletTokenViewModel) -> WalletFormItemView?
    func defineViewForSoraReceiverViewModel(_ model: WalletSoraReceiverViewModel) -> WalletFormItemView?
    func defineViewForFeeViewModel(_ model: FeeViewModelProtocol) -> WalletFormItemView?
}

final class WalletSoraDefinition: WalletSoraFormDefining {

    let binder: WalletFormViewModelBinderProtocol
    let itemViewFactory: WalletFormItemViewFactoryProtocol

    init(binder: WalletFormViewModelBinderProtocol, itemViewFactory: WalletFormItemViewFactoryProtocol) {
        self.binder = binder
        self.itemViewFactory = itemViewFactory
    }

    func defineViewForFeeViewModel(_ model: FeeViewModelProtocol) -> WalletFormItemView? {
        let view = R.nib.soraFeeView.firstView(owner: nil)!
        view.bind(viewModel: model)

        return view
    }

    func defineViewForSoraTokenViewModel(_ model: WalletTokenViewModel) -> WalletFormItemView? {
        let view =  R.nib.soraAssetView.firstView(owner: nil)!

        view.bind(viewModel: model)
        
        return view
    }

    func defineViewForSpentAmountModel(_ model: WalletFormSpentAmountModel) -> WalletFormItemView? {
        let view = R.nib.soraAmountInputView.firstView(owner: nil)!

        view.bind(viewModel: model)

        return view
    }

    func defineViewForTokenViewModel(_ model: WalletFormTokenViewModel) -> WalletFormItemView? {
        let view = itemViewFactory.createTokenView()
        binder.bind(viewModel: model, to: view)
        view.borderType = []
        return view
    }

    func defineViewForSoraReceiverViewModel(_ model: WalletSoraReceiverViewModel) -> WalletFormItemView? {
        let view = R.nib.soraReceiverView.firstView(owner: nil)!
        view.bind(viewModel: model)
        return view
    }
}
