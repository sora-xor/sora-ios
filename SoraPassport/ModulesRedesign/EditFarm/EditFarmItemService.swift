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

final class EditFarmItemService: EditFarmItemServiceProtocol {
    @Published var feeText: String?
    @Published var networkFeeAmount: String = ""
    @Published var buttonEnabled: Bool = false
    
    private var feeInfo: (depositFee: Decimal, withdrawFee: Decimal)?
    
    private let userFarm: UserFarm
    private let currentPercentage: Float
    private let feePercentage: Decimal
    
    private let feeProvider: FeeProviderProtocol
    private let callFactory = SubstrateCallFactory()
    private var cancellables = Set<AnyCancellable>()
    private let output: PassthroughSubject<Void, Never> = .init()
    
    init(userFarm: UserFarm, feeProvider: FeeProviderProtocol, currentPercentage: Float, feePercentage: Decimal) {
        self.userFarm = userFarm
        self.feeProvider = feeProvider
        self.currentPercentage = currentPercentage
        self.feePercentage = feePercentage
    }
    
    func setup() {
        Task { [weak self] in
            self?.feeInfo = try? await self?.loadFeeInfo()
        }
    }
    
    func transform(input: AnyPublisher<Float, Never>) -> AnyPublisher<Void, Never> {
        input.sink { [weak self] percentage in
            guard let self else { return }
            
            let feePercentage = percentage * 100 > currentPercentage ? feePercentage : 0
            feeText = "\(feePercentage)%"
            
            if let feeInfo = self.feeInfo {
                let feeAmount = percentage > currentPercentage ? feeInfo.depositFee : feeInfo.withdrawFee
                let feeText = NumberFormatter.cryptoAssets.stringFromDecimal(feeAmount) ?? ""
                networkFeeAmount = feeText + " XOR"
            }

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
