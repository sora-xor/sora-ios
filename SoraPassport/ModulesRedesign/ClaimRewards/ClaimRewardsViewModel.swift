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

import UIKit
import SoraUIKit
import RobinHood
import SoraFoundation
import sorawallet
import Combine

final class ClaimRewardsViewModel {
    @Published var snapshot: ClaimRewardsSnapshot = ClaimRewardsSnapshot()
    var snapshotPublisher: Published<ClaimRewardsSnapshot>.Publisher { $snapshot }
    private var cancellables: Set<AnyCancellable> = []
    
    weak var view: ClaimRewardsViewProtocol?
    
    var farm: Farm
    var poolInfo: PoolInfo
    var fiatService: FiatServiceProtocol?
    private weak var assetsProvider: AssetProviderProtocol?
    private let detailsFactory: DetailViewModelFactoryProtocol
    private let itemFactory = ClaimRewardsItemFactory()
    private let service: ClaimRewardsServiceProtocol
    private let walletService: WalletServiceProtocol
    private let wireframe: ConfirmTransactionWireframeProtocol
    private let assetManager: AssetManagerProtocol
    private var pricesObservation: PIPricesObservation?
    private let reviewedAccount: AccountItem?
    private var feeRequestID: UUID?
    private var loadTask: Task<Void, Never>?
    private var isSubmitting = false

    private struct Submission {
        let farm: UserFarm
        let fee: Decimal
        let sender: String
    }
    
    private var userFarmInfo: UserFarm? {
        didSet {
            reload()
        }
    }
    
    private var fee: Decimal = 0 {
        didSet {
            reload()
        }
    }
    
    private var fiatData: [PIExactFiatData] = [] {
        didSet {
            reload()
        }
    }
    
    private var assetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            reload()
        }
   }

    init(farm: Farm,
         poolInfo: PoolInfo,
         fiatService: FiatServiceProtocol?,
         assetsProvider: AssetProviderProtocol?,
         detailsFactory: DetailViewModelFactoryProtocol,
         service: ClaimRewardsServiceProtocol,
         walletService: WalletServiceProtocol,
         wireframe: ConfirmTransactionWireframeProtocol,
         assetManager: AssetManagerProtocol
    ) {
        self.farm = farm
        self.poolInfo = poolInfo
        self.fiatService = fiatService
        self.assetsProvider = assetsProvider
        self.detailsFactory = detailsFactory
        self.service = service
        self.walletService = walletService
        self.wireframe = wireframe
        self.assetManager = assetManager
        reviewedAccount = SelectedWalletSettings.shared.currentAccount
    }
    
    deinit {
        loadTask?.cancel()
    }

}

extension ClaimRewardsViewModel: ClaimRewardsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        loadTask?.cancel()
        let requestID = UUID()
        feeRequestID = requestID
        fee = 0
        assetBalance = currentFeeBalance() ?? BalanceData(
            identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)
        )
        userFarmInfo = poolInfo.farms.first {
            $0.baseAssetId == farm.baseAsset?.assetId &&
            $0.poolAssetId == farm.poolAsset?.assetId &&
            $0.rewardAssetId == farm.rewardAsset?.assetId
        }
        guard let userFarmInfo, selectedAccountMatchesReview() else { return }
        let feeService = service
        let priceService = fiatService
        loadTask = Task { @MainActor [weak self] in
            let fee = try? await feeService.getFee(
                for: userFarmInfo.baseAssetId,
                targetAssetId: userFarmInfo.poolAssetId,
                rewardAssetId: userFarmInfo.rewardAssetId,
                isFarm: userFarmInfo.isFarm
            )
            guard !Task.isCancelled, self?.feeRequestID == requestID else { return }
            self?.fee = fee.flatMap { !$0.isNaN && $0 > 0 ? $0 : nil } ?? 0
            let prices = await priceService?.getFiat() ?? []
            guard !Task.isCancelled, self?.feeRequestID == requestID else { return }
            self?.fiatData = prices
        }
        pricesObservation = PIPricesObservation { [weak self] in
            Task { @MainActor [weak self] in
                let prices = await priceService?.getFiat() ?? []
                guard self?.feeRequestID == requestID else { return }
                self?.fiatData = prices
            }
        }
    }

    private func selectedAccountMatchesReview() -> Bool {
        guard let reviewedAccount, let current = SelectedWalletSettings.shared.currentAccount else { return false }
        return current.address == reviewedAccount.address && current.publicKeyData == reviewedAccount.publicKeyData &&
            current.cryptoType == reviewedAccount.cryptoType && current.networkType == reviewedAccount.networkType &&
            current.isSelected && reviewedAccount.isSelected
    }

    private func currentFeeBalance() -> BalanceData? {
        let xor = WalletAssetId.xor.rawValue
        guard let assetsProvider,
              !assetsProvider.unavailableBalanceAssetIds(among: [xor]).contains(xor) else { return nil }
        let balances = assetsProvider.getBalances(with: [xor]).filter { $0.identifier == xor }
        guard balances.count == 1, let balance = balances.first,
              !balance.balance.decimalValue.isNaN, balance.balance.decimalValue >= 0 else { return nil }
        return balance
    }

    private func reload() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> ClaimRewardsSnapshot {
        var snapshot = ClaimRewardsSnapshot()
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> ClaimRewardsSection {
        var items: [ClaimRewardsSectionItem] = []
        
        let rewardsItem = itemFactory.createClaimRewardsItem(farm: farm,
                                                             userFarmInfo: userFarmInfo,
                                                             poolInfo: poolInfo,
                                                             userBalance: assetBalance.balance.decimalValue,
                                                             fee: fee,
                                                             fiatData: fiatData,
                                                             detailsFactory: detailsFactory,
                                                             viewModel: self)
        
        rewardsItem.claimPossible = rewardsItem.claimPossible && !isSubmitting && selectedAccountMatchesReview()
        items.append(.claim(rewardsItem))
        
        return ClaimRewardsSection(items: items)
    }
    
    func networkFeeInfoButtonTapped() {
        present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func claimButtonTapped() {
        guard !isSubmitting else { return }
        assetBalance = currentFeeBalance() ?? BalanceData(
            identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)
        )
        guard let userFarmInfo, let reviewedAccount,
              selectedAccountMatchesReview(),
              let rewards = userFarmInfo.rewards, !rewards.isNaN, rewards > 0,
              !fee.isNaN, fee > 0,
              assetBalance.balance.decimalValue > fee else { return }
        let submission = Submission(farm: userFarmInfo, fee: fee, sender: reviewedAccount.address)

        let context: [String: String] = [
            TransactionContextKeys.transactionType: TransactionType.demeterClaimReward.rawValue,
            TransactionContextKeys.rewardAsset: userFarmInfo.rewardAssetId,
            TransactionContextKeys.isFarm: userFarmInfo.isFarm ? "1" : "0",
            
        ]
        
        let transferInfo = TransferInfo(
            source: userFarmInfo.baseAssetId,
            destination: userFarmInfo.poolAssetId,
            amount: AmountDecimal(value: 0),
            asset: "",
            details: "",
            fees: [],
            context: context
        )
        
        isSubmitting = true
        reload()
        wireframe.showActivityIndicator()
        walletService.transfer(info: transferInfo, runCompletionIn: .main) { [weak self] optionalResult in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isSubmitting = false
                reload()
                wireframe.hideActivityIndicator()
                if let result = optionalResult {
                    handleTransfer(result: result, submission: submission)
                }
            }
        }
    }
    
    private func handleTransfer(result: Result<Data, Swift.Error>, submission: Submission) {
        let userFarmInfo = submission.farm
        
        var status: TransactionBase.Status = .pending
        var txHash = ""
        if case .failure = result {
            status = .failed
        }
        if case let .success(hex) = result {
            txHash = hex.toHex(includePrefix: true)
        }
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: submission.fee * pow(10, 18)),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        
        let transaction = ClaimReward(base: base,
                                      amount: Amount(value: userFarmInfo.rewards ?? Decimal(0)),
                                      peer: submission.sender,
                                      rewardTokenId: userFarmInfo.rewardAssetId)
        
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction, accountAddress: submission.sender))
        wireframe.showActivityDetails(on: view?.controller, model: transaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: {})
        }
    }
}
