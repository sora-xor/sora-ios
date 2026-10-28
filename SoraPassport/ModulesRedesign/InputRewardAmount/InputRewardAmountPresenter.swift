// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit

import BigInt
import SoraUIKit

protocol InputRewardAmountPresenterOutput: AnyObject {
    func updateReferral(balance: Decimal)
    func showAlert(withSuccess isSuccess: Bool)
    func showTransactionDetails(from controller: UIViewController?,
                                result: Result<String, Swift.Error>,
                                fee: Decimal,
                                amount: Decimal,
                                type: ReferralBondTransaction.ReferralTransactionType,
                                completion: (() -> Void)?)
}

final class InputRewardAmountPresenter: InvitationsCellDelegate {
    weak var view: InputRewardAmountViewInput?
    weak var output: InputRewardAmountPresenterOutput?
    private var fee: Decimal
    private var previousBondedAmount: Decimal
    private var currentBondedAmount: Decimal
    private var type: InputRewardAmountType
    private var interactor: InputRewardAmountInteractorInputProtocol
    private let feeAsset: AssetInfo
    weak var viewModel: InvitationsViewModel?

    private var items: [CellViewModel] = []
    private var currentBalance: Decimal = Decimal(0)
    private var actionButtonIsEnabled: Bool = false
    private var currentBoundingAmount: Decimal = Decimal(0)

    init(fee: Decimal,
         previousBondedAmount: Decimal,
         type: InputRewardAmountType,
         interactor: InputRewardAmountInteractorInputProtocol,
         feeAsset: AssetInfo) {
        self.fee = fee
        self.previousBondedAmount = previousBondedAmount
        self.currentBondedAmount = previousBondedAmount
        self.type = type
        self.interactor = interactor
        self.feeAsset = feeAsset
    }
}

extension InputRewardAmountPresenter: InputRewardAmountViewOutput {
    func willMove() {
        interactor.getBalance()
        view?.setupTitle(with: type.screenTitle)
    }
}

extension InputRewardAmountPresenter: InputRewardAmountViewDelegate {

}

extension InputRewardAmountPresenter: InputRewardAmountInteractorOutputProtocol {
    func received(_ balance: Decimal) {
        let balanceText = (NumberFormatter.cryptoAssets.stringFromDecimal(balance) ?? "") + " \(feeAsset.symbol)"
        let feeAmount = "\(fee) \(feeAsset.symbol)"
        let actionButtonIsEnabled = type == .unbond ? fee <= balance : false
        let item = InvitationsViewModel(title: type.title,
                                        description: type.descriptionText(with: feeAmount) ,
                                        fee: fee,
                                        feeSymbol: feeAsset.symbol,
                                        balance: balanceText,
                                        bondedAmount: type == .bond ? 0 : currentBondedAmount,
                                        buttonTitle: type.buttonTitle,
                                        isEnabled: actionButtonIsEnabled,
                                        delegate: self)
        
        items.append(item)
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }

        viewModel = item
        self.currentBalance = balance
    }

    func referralBalanceOperationReceived(with result: Result<String, Error>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if case .success = result {
                let newBalanceAfterBond = self.currentBondedAmount + self.previousBondedAmount
                let newBalanceAfterUnbond = self.previousBondedAmount - self.currentBondedAmount
                let balance = self.type == .bond ? newBalanceAfterBond : newBalanceAfterUnbond
                self.output?.updateReferral(balance: balance)
            }
            
            self.output?.showTransactionDetails(from: self.view?.controller,
                                                result: result,
                                                fee: self.fee,
                                                amount: self.currentBondedAmount,
                                                type: self.type != .bond ? .unbond : .bond,
                                                completion: {
                self.view?.pop()
            })
        }
    }
}

extension InputRewardAmountPresenter: ButtonCellDelegate {
    func buttonTapped() {
        interactor.sendReferralBalanceRequest(with: type, decimalBalance: currentBondedAmount)
    }
    
    func isMinusEnabled(_ currentInvitationCount: Decimal) -> Bool {
        currentInvitationCount > 0
    }

    func isPlusEnabled(_ currentInvitationCount: Decimal) -> Bool {
        switch type {
        case .bond:
            return isBalanceEnoughToBond(currentInvitationCount + 1)
        case .unbond:
            return isPreviousBondedEnoughToUnbond(currentInvitationCount + 1) && isBalanceEnoughToUnbond()
        }
    }

    func userChanged(_ currentInvitationCount: Decimal) {
        guard let viewModel = viewModel else { return }
        currentBondedAmount = currentInvitationCount * fee
        viewModel.isEnabled = isActionButtonEnabled(currentInvitationCount)
    }
    
    func networkFeeInfoButtonTapped() {
        present(message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
                title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                from: view
        )
    }

    private func isActionButtonEnabled(_ invitations: Decimal) -> Bool {
        switch type {
        case .bond:
            return isBalanceEnoughToBond(invitations) && invitations > 0
        case .unbond:
            return isBalanceEnoughToUnbond() && isPreviousBondedEnoughToUnbond(invitations) && invitations > 0
        }
    }

    private func isBalanceEnoughToBond(_ invitations: Decimal) -> Bool {
        let bondedAmount = invitations * fee
        return bondedAmount + fee <= currentBalance
    }


    private func isBalanceEnoughToUnbond() -> Bool {
        fee <= currentBalance
    }

    private func isPreviousBondedEnoughToUnbond(_ invitations: Decimal) -> Bool {
        return invitations * fee <= previousBondedAmount
    }
}
