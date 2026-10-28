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
import Combine
import BigInt


protocol EditFarmItemServiceProtocol {
    func setup()
}

enum FarmTransaction {
    case deposit
    case withdraw
    
    var transactionType: TransactionType {
        switch self {
        case .deposit:
            return TransactionType.demeterDeposit
        case .withdraw:
            return TransactionType.demeterWithdraw
        }
    }
}

final class EditFarmItemService: EditFarmItemServiceProtocol {
    @Published var isMaxButtonHidden: Bool = false
    @Published var confirmButtonEnabled: Bool = false
    @Published var feeText: String?
    @Published var networkFeeText: String = ""
    @Published var percentageText: String = ""
    @Published var willBePercentageText: String = ""
    
    var amount: Decimal = Decimal(0)
    var farmTransaction: FarmTransaction = .deposit
    var networkFeeAmount: Decimal = Decimal(0)
    
    private var feeInfo: (depositFee: Decimal, withdrawFee: Decimal)? {
        didSet {
            guard let feeInfo else { return }
            let feeText = NumberFormatter.cryptoAssets.stringFromDecimal(feeInfo.depositFee) ?? ""
            networkFeeText = feeText + " XOR"
        }
    }
    
    private let poolInfo: PoolInfo
    private let userFarm: UserFarm
    private let currentPercentage: Float
    private let feePercentage: Decimal
    
    private let feeProvider: FeeProviderProtocol
    private let userBalance: Decimal
    private let callFactory = SubstrateCallFactory()
    private var cancellables = Set<AnyCancellable>()
    private let output: PassthroughSubject<Void, Never> = .init()
    
    init(poolInfo: PoolInfo, userFarm: UserFarm, feeProvider: FeeProviderProtocol, currentPercentage: Float, feePercentage: Decimal, userBalance: Decimal) {
        self.userFarm = userFarm
        self.feeProvider = feeProvider
        self.currentPercentage = currentPercentage * 100
        self.feePercentage = feePercentage
        self.poolInfo = poolInfo
        self.userBalance = userBalance
    }
    
    func setup() {
        Task { [weak self] in
            self?.feeInfo = try? await self?.loadFeeInfo()
        }
    }
    
    func transform(input: AnyPublisher<Float, Never>) -> AnyPublisher<Void, Never> {
        input.sink { [weak self] value in
            guard let self else { return }
            
            farmTransaction = value > currentPercentage ? .deposit : .withdraw
            
            isMaxButtonHidden = value == 100

            let percent = NumberFormatter.percent.string(from: value as NSNumber) ?? ""
            percentageText = percent + "%"
            
            let feePercentage = value > currentPercentage ? feePercentage : 0
            feeText = "\(feePercentage)%"
            
            if let feeInfo = self.feeInfo {
                networkFeeAmount = value > currentPercentage ? feeInfo.depositFee : feeInfo.withdrawFee
                
                let feeText = NumberFormatter.cryptoAssets.stringFromDecimal(networkFeeAmount) ?? ""
                networkFeeText = feeText + " XOR"

                confirmButtonEnabled = userBalance > networkFeeAmount && value != currentPercentage
            }
            
            let accountPoolBalance = poolInfo.accountPoolBalance ?? Decimal(0)
            let pooledTokens = userFarm.pooledTokens ?? Decimal(0)

            amount = abs((accountPoolBalance * (value / Float(100)).toDecimal()) - pooledTokens)
            let feeAmount = value > currentPercentage ? amount * feePercentage / 100 : 0
            let stakingAmountWithoutFee = amount - feeAmount
            
            var shareWillBe = ((stakingAmountWithoutFee + pooledTokens) / (accountPoolBalance - feeAmount)) * 100

            if value.toDecimal() < shareWillBe {
                shareWillBe = Decimal(Double(value))
            }

            let shareWillBePercent = NumberFormatter.percent.stringFromDecimal(shareWillBe) ?? ""
            willBePercentageText = shareWillBePercent + "%"

        }.store(in: &cancellables)
        return output.eraseToAnyPublisher()
    }
}

private extension EditFarmItemService {
    private func loadFeeInfo() async throws -> (depositFee: Decimal, withdrawFee: Decimal) {
        let depositFee = try await getDepositFee()
        let withdrawFee = try await getWithdrawFee()
        return (depositFee: depositFee, withdrawFee: withdrawFee)
    }
    
    func getDepositFee() async throws -> Decimal {
        let call = try callFactory.depositLiquidityToDemeterFarmCall(baseAssetId: userFarm.baseAssetId,
                                                                     targetAssetId: userFarm.poolAssetId,
                                                                     rewardAssetId: userFarm.rewardAssetId,
                                                                     isFarm: userFarm.isFarm,
                                                                     amount: BigUInt(1))
        
        return await feeProvider.getFee(for: call)
    }
    
    func getWithdrawFee() async throws -> Decimal {
        let call = try callFactory.withdrawLiquidityFromDemeterFarmCall(baseAssetId: userFarm.baseAssetId,
                                                                        targetAssetId: userFarm.poolAssetId,
                                                                        rewardAssetId: userFarm.rewardAssetId,
                                                                        isFarm: userFarm.isFarm,
                                                                        amount: BigUInt(1))
        
        return await feeProvider.getFee(for: call)
    }
}

extension Float {
    func toDecimal() -> Decimal {
        return Decimal(Double(self))
    }
}
