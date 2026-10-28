// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
    private var currentInvitationCount: Decimal = 0
    private var submittedAmount: Decimal?

    init(fee: Decimal,
         previousBondedAmount: Decimal,
         type: InputRewardAmountType,
         interactor: InputRewardAmountInteractorInputProtocol,
         feeAsset: AssetInfo) {
        self.fee = fee
        self.previousBondedAmount = previousBondedAmount
        let count = type == .unbond && fee > 0 ? (previousBondedAmount / fee).rounded(mode: .down) : 0
        self.currentInvitationCount = max(count, 0)
        self.currentBondedAmount = max(count, 0) * fee
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
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.received(balance) }
            return
        }
        self.currentBalance = balance
        let balanceText = (NumberFormatter.cryptoAssets.stringFromDecimal(balance) ?? "") + " \(feeAsset.symbol)"
        let feeAmount = "\(fee) \(feeAsset.symbol)"
        let actionButtonIsEnabled = submittedAmount == nil && isActionButtonEnabled(currentInvitationCount)
        let item = InvitationsViewModel(title: type.title,
                                        description: type.descriptionText(with: feeAmount) ,
                                        fee: fee,
                                        feeSymbol: feeAsset.symbol,
                                        balance: balanceText,
                                        bondedAmount: currentBondedAmount,
                                        buttonTitle: type.buttonTitle,
                                        isEnabled: actionButtonIsEnabled,
                                        delegate: self)
        
        items = [item]
        
        viewModel = item
        view?.setup(with: items)
    }

    func referralBalanceOperationReceived(with result: Result<String, Error>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let amount = self.submittedAmount ?? self.currentBondedAmount
            self.submittedAmount = nil
            self.viewModel?.isEnabled = self.isActionButtonEnabled(self.currentInvitationCount)
            if case .success = result {
                let newBalanceAfterBond = amount + self.previousBondedAmount
                let newBalanceAfterUnbond = self.previousBondedAmount - amount
                let balance = self.type == .bond ? newBalanceAfterBond : newBalanceAfterUnbond
                self.output?.updateReferral(balance: balance)
            }
            
            self.output?.showTransactionDetails(from: self.view?.controller,
                                                result: result,
                                                fee: self.fee,
                                                amount: amount,
                                                type: self.type != .bond ? .unbond : .bond,
                                                completion: {
                self.view?.pop()
            })
        }
    }
}

extension InputRewardAmountPresenter: ButtonCellDelegate {
    func buttonTapped() {
        guard submittedAmount == nil, viewModel?.isEnabled == true, isActionButtonEnabled(currentInvitationCount) else { return }
        submittedAmount = currentBondedAmount
        viewModel?.isEnabled = false
        interactor.sendReferralBalanceRequest(with: type, decimalBalance: currentBondedAmount)
    }
    
    func isMinusEnabled(_ currentInvitationCount: Decimal) -> Bool {
        currentInvitationCount > 0
    }

    func isPlusEnabled(_ currentInvitationCount: Decimal) -> Bool {
        guard validCount(currentInvitationCount), fee > 0 else { return false }
        switch type {
        case .bond:
            return isBalanceEnoughToBond(currentInvitationCount + 1)
        case .unbond:
            return isPreviousBondedEnoughToUnbond(currentInvitationCount + 1) && isBalanceEnoughToUnbond()
        }
    }

    func userChanged(_ currentInvitationCount: Decimal) {
        guard let viewModel = viewModel else { return }
        self.currentInvitationCount = currentInvitationCount
        currentBondedAmount = currentInvitationCount * fee
        viewModel.isEnabled = submittedAmount == nil && isActionButtonEnabled(currentInvitationCount)
    }
    
    func networkFeeInfoButtonTapped() {
        present(message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
                title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                from: view
        )
    }

    private func validCount(_ count: Decimal) -> Bool {
        count >= 0 && count.rounded(mode: .down) == count
    }

    private func isActionButtonEnabled(_ invitations: Decimal) -> Bool {
        guard validCount(invitations), fee > 0 else { return false }
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
