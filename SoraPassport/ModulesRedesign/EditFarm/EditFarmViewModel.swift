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

final class EditFarmViewModel {
    @Published var snapshot: EditFarmSnapshot = EditFarmSnapshot()
    var snapshotPublisher: Published<EditFarmSnapshot>.Publisher { $snapshot }
    
    weak var view: EditFarmViewProtocol?
    
    var farm: Farm
    var poolInfo: PoolInfo
    var userFarmInfo: UserFarm?
    private weak var assetsProvider: AssetProviderProtocol?
    private let itemFactory = EditFarmItemFactory()
    private let feeProvider: FeeProviderProtocol
    private var service: EditFarmItemService?
    private let walletService: WalletServiceProtocol
    private let wireframe: ConfirmTransactionWireframeProtocol
    private let assetManager: AssetManagerProtocol
    
    internal var sharePercentage: Decimal = 0
    private var fee: Decimal = 0
    private var isSubmitting = false
    private let reviewedAccount = SelectedWalletSettings.shared.currentAccount

    private struct Submission {
        let farm: UserFarm
        let amount: Decimal
        let fee: Decimal
        let transaction: FarmTransaction
        let sender: String
    }
    
    private var stakedSelection: FarmShareSelection = .zero

    init(farm: Farm,
         poolInfo: PoolInfo,
         assetsProvider: AssetProviderProtocol?,
         feeProvider: FeeProviderProtocol,
         walletService: WalletServiceProtocol,
         wireframe: ConfirmTransactionWireframeProtocol,
         assetManager: AssetManagerProtocol) {
        self.farm = farm
        self.poolInfo = poolInfo
        self.assetsProvider = assetsProvider
        self.feeProvider = feeProvider
        self.walletService = walletService
        self.wireframe = wireframe
        self.assetManager = assetManager
    }
    
    deinit {
        print("deinited")
    }

}

extension EditFarmViewModel: EditFarmViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
        loadFarmInfo()
        reload()
    }
    
    private func reload() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> EditFarmSnapshot {
        var snapshot = EditFarmSnapshot()
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> EditFarmSection {
        var items: [EditFarmSectionItem] = []
        
        if let userFarmInfo, let balance = assetsProvider?.getBalances(with: [WalletAssetId.xor.rawValue]).first {
            
            service = EditFarmItemService(poolInfo: poolInfo,
                                              userFarm: userFarmInfo,
                                              feeProvider: feeProvider,
                                              currentSelection: stakedSelection,
                                              feePercentage: farm.depositFee,
                                              userBalance: balance.balance.decimalValue)
            service?.setup()
            
            let editFarmItem = itemFactory.createEditFarmItem(stakeFeeAmount: farm.depositFee,
                                                              sharePercentage: sharePercentage,
                                                              stakedSelection: stakedSelection,
                                                              viewModel: self,
                                                              service: service)
            items.append(.stake(editFarmItem))
        }
        
        return EditFarmSection(items: items)
    }
    
    func loadFarmInfo() {
       userFarmInfo = poolInfo.farms.first {
           $0.baseAssetId == farm.baseAsset?.assetId &&
           $0.poolAssetId == farm.poolAsset?.assetId &&
           $0.rewardAssetId == farm.rewardAsset?.assetId
       }
        
        let pooledTokens = userFarmInfo?.pooledTokens  ?? .zero
        let accountPoolBalance = poolInfo.accountPoolBalance ?? .zero
        let sharePercentage = accountPoolBalance > 0 ? pooledTokens / accountPoolBalance * 100 : 0
        self.sharePercentage = sharePercentage
        self.stakedSelection = FarmShareSelection(percent: sharePercentage) ?? .zero
    }
    
    func feeInfoButtonTapped() {
        present(
            message: R.string.localizable.demeterFarmingDepositFeeHint(preferredLanguages: .currentLocale),
            title: R.string.localizable.commonFee(preferredLanguages: .currentLocale) ,
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func networkFeeInfoButtonTapped() {
        present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }

    func confirmButtonTapped() {
        guard !isSubmitting, let service, service.confirmButtonEnabled,
              let userFarmInfo, let reviewedAccount,
              let currentAccount = SelectedWalletSettings.shared.currentAccount,
              currentAccount.isSelected,
              currentAccount.address == reviewedAccount.address,
              currentAccount.publicKeyData == reviewedAccount.publicKeyData,
              currentAccount.cryptoType == reviewedAccount.cryptoType,
              currentAccount.networkType == reviewedAccount.networkType else { return }
        let xor = WalletAssetId.xor.rawValue
        let balances = assetsProvider?.getBalances(with: [xor]).filter { $0.identifier == xor } ?? []
        guard assetsProvider?.unavailableBalanceAssetIds(among: [xor]).contains(xor) != true,
              balances.count == 1, balances[0].balance.decimalValue >= service.networkFeeAmount else {
            service.confirmButtonEnabled = false
            return
        }
        let submission = Submission(farm: userFarmInfo, amount: service.amount,
                                    fee: service.networkFeeAmount, transaction: service.farmTransaction,
                                    sender: reviewedAccount.address)
        let context: [String: String] = [
            TransactionContextKeys.transactionType: service.farmTransaction.transactionType.rawValue,
            TransactionContextKeys.rewardAsset: userFarmInfo.rewardAssetId,
            TransactionContextKeys.isFarm: userFarmInfo.isFarm ? "1" : "0",
        ]
        
        let transferInfo = TransferInfo(
            source: userFarmInfo.baseAssetId,
            destination: userFarmInfo.poolAssetId,
            amount: AmountDecimal(value: service.amount),
            asset: "",
            details: "",
            fees: [],
            context: context
        )
        
        isSubmitting = true
        wireframe.showActivityIndicator()
        walletService.transfer(info: transferInfo, runCompletionIn: .main) { [weak self] optionalResult in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isSubmitting = false
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
        
        let transaction = FarmLiquidity(base: base,
                                        firstTokenId: userFarmInfo.baseAssetId,
                                        secondTokenId: userFarmInfo.poolAssetId,
                                        rewardTokenId: userFarmInfo.rewardAssetId,
                                        amount: Amount(value: submission.amount),
                                        sender: submission.sender,
                                        type: submission.transaction == .deposit ? .add : .withdraw)
        
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction, accountAddress: submission.sender))
        wireframe.showActivityDetails(on: view?.controller, model: transaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: {})
        }
    }
}
