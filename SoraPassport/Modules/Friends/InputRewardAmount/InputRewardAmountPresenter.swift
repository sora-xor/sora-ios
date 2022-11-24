/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import CommonWallet
import BigInt

protocol InputRewardAmountPresenterOutput: AnyObject {
    func updateReferral(balance: Decimal)
    func showAlert(withSuccess isSuccess: Bool)
}

final class InputRewardAmountPresenter {
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
        view?.setupTitle(with: type.screenTitle.uppercased())
    }
}

extension InputRewardAmountPresenter: InputRewardAmountViewDelegate {

}

extension InputRewardAmountPresenter: InputRewardAmountInteractorOutputProtocol {
    func received(_ balance: Decimal) {
        items.append(SpaceViewModel(height: 24, backgroundColor: .clear))

        if type == .bond {
            items.append(TextViewModel(title: type.title,
                                       textColor: R.color.baseContentPrimary(),
                                       font: UIFont.styled(for: .title4)))

            items.append(SpaceViewModel(height: 16, backgroundColor: .clear))
        }

        items.append(TextViewModel(title: type.descriptionText(with: "\(fee) \(feeAsset.symbol)"),
                                   textColor: R.color.baseContentPrimary(),
                                   font: UIFont.styled(for: .paragraph1)))

        items.append(SpaceViewModel(height: 24, backgroundColor: .clear))

        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.maximumFractionDigits = Int(feeAsset.precision)
        formatter.decimalSeparator = "."
        let balanceText = (formatter.stringFromDecimal(balance) ?? "") + " \(feeAsset.symbol)"

        items.append(AmountViewModel(currentBalance: balanceText,
                                     bondedAmount: type == .bond ? 0 : currentBondedAmount,
                                     fee: fee,
                                     delegate: self))

        items.append(SpaceViewModel(height: 24, backgroundColor: .clear))

        let feeText = R.string.localizable.polkaswapNetworkFee(preferredLanguages: .currentLocale) + ": \(fee) \(feeAsset.symbol)"
        items.append(TextViewModel(title: feeText,
                                   textColor: R.color.neumorphism.brown(),
                                   font: UIFont.styled(for: .paragraph1),
                                   textAligment: .center))

        items.append(SpaceViewModel(height: 8, backgroundColor: .clear))

        let actionButtonIsEnabled = type == .unbond ? fee <= balance : false
        items.append(ButtonViewModel(title: type.buttonTitle,
                                     isEnabled: actionButtonIsEnabled,
                                     delegate: self))

        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }

        self.currentBalance = balance
        self.actionButtonIsEnabled = actionButtonIsEnabled
    }

    func referralBalanceOperationReceived(withSuccess isSuccess: Bool) {
        DispatchQueue.main.async {
            self.view?.dismiss { [weak self] in
                guard let self = self else { return }
                self.output?.showAlert(withSuccess: isSuccess)

                guard isSuccess else { return }
                let newBalanceAfterBond = self.currentBondedAmount + self.previousBondedAmount
                let newBalanceAfterUnbond = self.previousBondedAmount - self.currentBondedAmount
                let balance = self.type == .bond ? newBalanceAfterBond : newBalanceAfterUnbond
                self.output?.updateReferral(balance: balance)
            }
        }
    }
}

extension InputRewardAmountPresenter: ButtonCellDelegate {
    func buttonTapped() {
        interactor.sendReferralBalanceRequest(with: type, decimalBalance: currentBondedAmount)
    }
}

extension InputRewardAmountPresenter: AmountCellDelegate {

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
        guard let buttonCellRow = items.firstIndex(where: { $0 is ButtonViewModel }),
                self.actionButtonIsEnabled != isEnabled else { return }

        (items[buttonCellRow] as? ButtonViewModel)?.isEnabled = isEnabled
        self.actionButtonIsEnabled = isEnabled

        let buttonCellIndexPath = IndexPath(row: buttonCellRow, section: 0)
        self.view?.reloadCell(at: buttonCellIndexPath, models: items)
    }
}
