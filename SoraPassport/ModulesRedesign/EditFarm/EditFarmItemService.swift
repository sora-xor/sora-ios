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
import Combine
import BigInt
import CommonWallet

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
