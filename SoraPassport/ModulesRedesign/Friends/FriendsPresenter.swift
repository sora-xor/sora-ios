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
import SoraKeystore
import SoraFoundation
import SoraUI
import BigInt
import sorawallet
import SSFUtils


extension FriendsPresenter {
    enum InvitationActionType: Int {
        case startInvite
        case enterLink
    }
}

final class FriendsPresenter {
    weak var view: FriendsViewProtocol?
    var wireframe: FriendsWireframeProtocol!
    var interactor: FriendsInteractorInputProtocol!

    private var isExpaned: Bool = false
    private var rewards: [ReferrerReward] = []
    private let settings: SettingsManagerProtocol
    private var setReferrerFee = Decimal(0)
    private var bondFee = Decimal(0)
    private var unbondFee = Decimal(0)
    private var referralBalance = Decimal(0)
    private var referrer = ""
    private var totalRewardRow = 0
    private let selectedAccount: AccountItem
    private let feeAsset: AssetInfo

    init(settings: SettingsManagerProtocol,
         keychain: KeystoreProtocol,
         selectedAccount: AccountItem,
         feeAsset: AssetInfo) {
        self.settings = settings
        self.selectedAccount = selectedAccount
        self.feeAsset = feeAsset
    }
}

// MARK: - Presenter Protocol

extension FriendsPresenter: FriendsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelectAction(_ action: FriendsPresenter.InvitationActionType) {
        guard let viewController = view?.controller else { return }

        switch action {
        case .startInvite:
            showInputRewardAmount(with: .bond)

        case .enterLink:
            guard referrer.isEmpty else {
                wireframe.showReferrerScreen(from: viewController, referrer: referrer)
                return
            }
            wireframe.showLinkInputViewController(from: viewController, delegate: self)
        }
    }
}

// MARK: - Interactor Output Protocol

extension FriendsPresenter: FriendsInteractorOutputProtocol {
    func updateReferrer(address: String) {
        self.referrer = address
        updateScreen()
    }

    func updateReferral(balance: Decimal) {
        self.referralBalance = balance
        updateScreen()
    }

    func updateReferral(rewards: [ReferrerReward]) {
        self.rewards = rewards
        updateScreen()
    }

    func didReceive(rewards: [ReferrerReward],
                    setReferrerFee: Decimal,
                    bondFee: Decimal,
                    unbondFee: Decimal,
                    referralBalance: Decimal,
                    referrer: String) {
        self.rewards = rewards
        self.setReferrerFee = setReferrerFee
        self.bondFee = bondFee
        self.unbondFee = unbondFee
        self.referralBalance = referralBalance
        self.referrer = referrer

        updateScreen()
    }
}

extension FriendsPresenter: InputLinkPresenterOutput {
    func setupReferrer(_ referrer: String) {
        self.referrer = referrer
        updateScreen()
    }

    func showAlert(withSuccess isSuccess: Bool) {
        DispatchQueue.main.async {

            let title = isSuccess ? R.string.localizable.walletTransactionSubmitted(preferredLanguages: .currentLocale) :
            R.string.localizable.walletTransactionRejected(preferredLanguages: .currentLocale)

            let image = isSuccess ? R.image.success() : R.image.iconClose()

            self.view?.showAlert(with: title, image: image)
        }
    }
    
    func showTransactionDetails(from controller: UIViewController?,
                                result: Result<String, Swift.Error>,
                                peerAddress: String,
                                completion: (() -> Void)?) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        
        switch result {
        case .success(let hash):
            txHash = hash
        case .failure:
            status = .failed
        }
        
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: 0),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
 
        let transaction = SetReferrerTransaction(base: base,
                                                 who: peerAddress,
                                                 isMyReferrer: true,
                                                 tokenId: WalletAssetId.xor.rawValue)

        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction))
        wireframe.showActivityDetails(from: controller, model: transaction, completion: completion)
    }
    
    func moveForward(controller: UIViewController?) {
        wireframe.setViewControllers(from: controller,
                                     currentController: view?.controller,
                                     referrer: referrer)
    }
}

extension FriendsPresenter: InputRewardAmountPresenterOutput {
    func showTransactionDetails(from controller: UIViewController?,
                                result: Result<String, Swift.Error>,
                                fee: Decimal,
                                amount: Decimal,
                                type: ReferralBondTransaction.ReferralTransactionType,
                                completion: (() -> Void)?) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        
        switch result {
        case .success(let hash):
            txHash = hash
        case .failure:
            status = .failed
        }
        
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: fee),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
 
        let transaction = ReferralBondTransaction(base: base,
                                                  amount: Amount(value: amount),
                                                  tokenId: WalletAssetId.xor.rawValue,
                                                  type: type)

        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction))
        wireframe.showActivityDetails(from: controller, model: transaction, completion: completion)
    }
}

extension FriendsPresenter: TotalRewardsCellDelegate {
    func expandButtonTapped() {
        isExpaned = !isExpaned

        let items = createItems()
        let indexs: [Int] = Array(totalRewardRow...(totalRewardRow + rewards.count))
        view?.reloadScreen(with: items, updatedIndexs: indexs, isExpanding: isExpaned)
    }
}

extension FriendsPresenter: ReferrerCellDelegate {
    func enterLinkButtonTapped() {
        guard let view = view?.controller else { return }
        wireframe.showLinkInputViewController(from: view, delegate: self)
    }
}

extension FriendsPresenter: AvailableInvitationsCellDelegate {
    func shareButtonTapped(with text: String) {
        showActivityViewController(with: text)
    }

    func changeBoundedAmount(to type: InputRewardAmountType) {
        showInputRewardAmount(with: type)
    }
}

extension FriendsPresenter {
    /// A referral reward in XOR, from the whole number of smallest units
    /// the indexer publishes. Text in any other form counts as no reward:
    /// `BigUInt(stringLiteral:)` stops the app on such text, so it is not
    /// used on anything read from the network.
    static func rewardAmount(_ smallestUnits: String) -> Decimal {
        guard
            !smallestUnits.isEmpty,
            smallestUnits.utf8.allSatisfy({ (0x30 ... 0x39).contains($0) }),
            let units = BigUInt(smallestUnits, radix: 10)
        else {
            return 0
        }
        return Decimal.fromSubstrateAmount(units, precision: 18) ?? 0
    }
}

private extension FriendsPresenter {
    func createItems() -> [CellViewModel] {

        let totalReward = rewards.reduce(Decimal(0)) { totalReward, reward in
            totalReward + Self.rewardAmount(reward.amount)
        }

        var items: [CellViewModel] = []

        let invitationCount = (referralBalance / setReferrerFee).rounded(mode: .down)
        items.append(AvailableInvitationsViewModel(accountAddress: selectedAccount.address,
                                                   invitationCount: invitationCount,
                                                   bondedAmount: referralBalance,
                                                   delegate: self))

        items.append(ReferrerViewModel(address: referrer, delegate: self))

        items.append(TotalRewardsViewModel(invetationCount: rewards.count,
                                           totalRewardsAmount: totalReward,
                                           assetSymbol: feeAsset.symbol,
                                           delegate: self))
        totalRewardRow = items.count

        if isExpaned {
            items.append(RewardSeparatorViewModel())

            for reward in rewards {
                let amount = Self.rewardAmount(reward.amount)
                items.append(RewardRawViewModel(title: reward.referral, amount: amount, assetSymbol: feeAsset.symbol))
            }
        }

        items.append(RewardFooterViewModel())

        return items
    }

    func updateScreen() {
        if referralBalance < setReferrerFee {
            DispatchQueue.main.async {
                self.view?.startInvitingScreen(with: self.referrer)
            }
            return
        }

        let items = createItems()

        DispatchQueue.main.async {
            self.view?.setup(with: items)
        }
    }

    func showInputRewardAmount(with type: InputRewardAmountType) {
        guard let view = view?.controller else { return }
        wireframe.showInputRewardAmountViewController(from: view,
                                                      fee: type == .bond ? bondFee : unbondFee,
                                                      bondedAmount: referralBalance,
                                                      type: type,
                                                      delegate: self)
    }

    func showActivityViewController(with shareText: String) {
        guard let view = view?.controller else { return }
        wireframe.showActivityViewController(from: view, shareText: shareText)
    }
}

// MARK: - Localizable

extension FriendsPresenter: Localizable {

    var locale: Locale {
        return localizationManager?.selectedLocale ?? Locale.current
    }

    var languages: [String] {
        return localizationManager?.preferredLocalizations ?? []
    }
}
