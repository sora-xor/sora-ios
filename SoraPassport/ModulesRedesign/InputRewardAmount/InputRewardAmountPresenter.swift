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
import CommonWallet
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
        
        items.append(InvitationsViewModel(title: type.title,
                                          description: type.descriptionText(with: feeAmount) ,
                                          fee: fee,
                                          feeSymbol: feeAsset.symbol,
                                          balance: balanceText,
                                          bondedAmount: type == .bond ? 0 : currentBondedAmount,
                                          buttonTitle: type.buttonTitle,
                                          isEnabled: actionButtonIsEnabled,
                                          delegate: self))
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }

        self.currentBalance = balance
        self.actionButtonIsEnabled = actionButtonIsEnabled
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
        currentBondedAmount = currentInvitationCount * fee
        let actionButtonIsEnabled = isActionButtonEnabled(currentInvitationCount)
        setActionButtonEnabled(actionButtonIsEnabled)
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

    private func setActionButtonEnabled(_ isEnabled: Bool) {
        guard let buttonCellRow = items.firstIndex(where: { $0 is InvitationsViewModel }),
                self.actionButtonIsEnabled != isEnabled else { return }

        (items[buttonCellRow] as? InvitationsViewModel)?.isEnabled = isEnabled
        (items[buttonCellRow] as? InvitationsViewModel)?.bondedAmount = currentBondedAmount
        self.actionButtonIsEnabled = isEnabled

        let buttonCellIndexPath = IndexPath(row: buttonCellRow, section: 0)
        self.view?.reloadCell(at: buttonCellIndexPath, models: items)
    }
}
