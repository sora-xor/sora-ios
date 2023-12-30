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

import UIKit
import SoraUIKit
import CommonWallet
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
    private let completion: (() -> Void)?
    
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
    
    private var fiatData: [FiatData] = [] {
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
         assetManager: AssetManagerProtocol,
         completion: (() -> Void)?
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
        self.completion = completion
    }
    
    deinit {
        print("deinited")
    }

}

extension ClaimRewardsViewModel: ClaimRewardsViewModelProtocol, AlertPresentable {
    func viewDidLoad() {
         userFarmInfo = poolInfo.farms.first {
            $0.baseAssetId == farm.baseAsset?.assetId &&
            $0.poolAssetId == farm.poolAsset?.assetId &&
            $0.rewardAssetId == farm.rewardAsset?.assetId
        }
        
        guard let userFarmInfo else { return }

        Task { [weak self] in

            do {
                self?.fee = try await self?.service.getFee(
                    for: userFarmInfo.baseAssetId,
                    targetAssetId: userFarmInfo.poolAssetId,
                    rewardAssetId: userFarmInfo.rewardAssetId,
                    isFarm: userFarmInfo.isFarm
                ) ?? Decimal(0)
            } catch {
                print("fee error: \(error)")
            }
            
            self?.fiatData = await self?.fiatService?.getFiat() ?? []
        }
        
        guard let balance = assetsProvider?.getBalances(with: [WalletAssetId.xor.rawValue]).first else { return }
        assetBalance = balance
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
        guard let userFarmInfo = userFarmInfo else { return }
        
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
        
        wireframe.showActivityIndicator()
        walletService.transfer(info: transferInfo, runCompletionIn: .main) { [weak self] (optionalResult) in
            self?.wireframe.hideActivityIndicator()

            if let result = optionalResult {
                self?.handleTransfer(result: result)
            }
        }
    }
    
    private func handleTransfer(result: Result<Data, Swift.Error>) {
        guard let userFarmInfo else { return }
        
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
                                   fee: Amount(value: fee * pow(10, 18)),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        
        let transaction = ClaimReward(base: base,
                                      amount: Amount(value: userFarmInfo.rewards ?? Decimal(0)),
                                      peer: SelectedWalletSettings.shared.currentAccount?.address ?? "",
                                      rewardTokenId: userFarmInfo.rewardAssetId)
        
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction))
        wireframe.showActivityDetails(on: view?.controller, model: transaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: self?.completion)
        }
    }
}


