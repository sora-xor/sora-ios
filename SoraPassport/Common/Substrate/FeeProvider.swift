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
import SSFUtils
import SoraKeystore
import BigInt
import IrohaCrypto

protocol FeeProviderProtocol {
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void)
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void)
    func getFee(for call: any RuntimeCallable) async -> Decimal
    func getFee(for type: TransactionType) async -> Decimal
}

final class FeeProvider: FeeProviderProtocol {

    private var feeStore: [String: Decimal] = [:]

    private var selectedAccount: AccountItem? {
        SelectedWalletSettings.shared.currentAccount
    }

    private var extrinsicService: ExtrinsicService {
        let selectedAccount = selectedAccount!
        let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())!
        let runtime = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())!
        return ExtrinsicService(address: selectedAccount.address,
                                                                                  cryptoType: selectedAccount.cryptoType,
                                                                                  runtimeRegistry: runtime,
                                                                                  engine: engine,
                                                                                  operationManager: OperationManagerFacade.sharedManager)
    }

    @available(*, renamed: "getFee(for:)")
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) {
        Task {
            let result = await getFee(for: type)
            completion(result)
        }
    }
    
    
    func getFee(for type: TransactionType) async -> Decimal {
        
        let dexId = "0"
        
        if let cached =  feeStore[type.rawValue] {
            return cached
        }
        var builderClosure: ExtrinsicBuilderClosure?
        switch type {
            
        case .outgoing:
            builderClosure = { [weak self] builder in
                let callFactory = SubstrateCallFactory()
                
                let accountId1 = try SS58AddressFactory().accountId(from: self?.selectedAccount?.address ?? "").toHex()
                let transferCall = try callFactory.transfer(to: accountId1,
                                                            asset: WalletAssetId.xor.rawValue,
                                                            amount: 0)
                
                return try builder
                    .adding(call: transferCall)
            }
            
        case .swap:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                
                let swapCall = try callFactory.swap(
                    from: WalletAssetId.xor.chainId,
                    to: WalletAssetId.val.chainId,
                    dexId: "0",
                    amountCall: [SwapVariant.desiredInput: SwapAmount(type: .desiredInput, desired: 0, slip: 0)],
                    type: [],
                    filter: 0
                )
                
                return try builder
                    .adding(call: swapCall)
            }
            
        case .liquidityAdd:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                
                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId,
                    assetA: WalletAssetId.xor.chainId,
                    assetB: WalletAssetId.val.chainId,
                    desiredA: 1,
                    desiredB: 1,
                    minA: 1,
                    minB: 1
                )
                
                return try builder
                    .adding(call: depositCall)
            }
        case .liquidityAddToExistingPoolFirstTime:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                let dexId1 = dexId
                let initializeCall = try callFactory.initializePool(dexId: dexId1,
                                                                    baseAssetId: WalletAssetId.xor.chainId,
                                                                    targetAssetId: WalletAssetId.val.chainId)
                
                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId1,
                    assetA: WalletAssetId.xor.chainId,
                    assetB: WalletAssetId.val.chainId,
                    desiredA: 1,
                    desiredB: 1,
                    minA: 1,
                    minB: 1
                )
                
                return try builder
                    .with(shouldUseAtomicBatch: true)
                // .adding(call: initializeCall) // TODO: fix fee calculations for AtomicBatch
                    .adding(call: depositCall)
            }
        case .liquidityAddNewPool:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                
                let registerCall = try callFactory.register(dexId: dexId,
                                                            baseAssetId: WalletAssetId.xor.chainId,
                                                            targetAssetId: WalletAssetId.val.chainId)
                
                let initializeCall = try callFactory.initializePool(dexId: dexId,
                                                                    baseAssetId: WalletAssetId.xor.chainId,
                                                                    targetAssetId: WalletAssetId.val.chainId)
                
                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId,
                    assetA: WalletAssetId.xor.chainId,
                    assetB: WalletAssetId.val.chainId,
                    desiredA: 1,
                    desiredB: 1,
                    minA: 1,
                    minB: 1
                )
                
                return try builder
                    .with(shouldUseAtomicBatch: true)
                    .adding(call: registerCall)
                    .adding(call: initializeCall)
                    .adding(call: depositCall)
            }
        case .liquidityRemoval:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                
                let withdrawCall = try callFactory.withdrawLiquidityCall(
                    dexId: dexId,
                    assetA: WalletAssetId.val.chainId,
                    assetB: WalletAssetId.val.chainId,
                    assetDesired: 1,
                    minA: 1,
                    minB: 1
                )
                
                return try builder
                    .adding(call: withdrawCall)
            }
        case .referral:
            builderClosure = { builder in
                let callFactory = SubstrateCallFactory()
                
                let addressFactory = SS58AddressFactory()
                let address = self.selectedAccount?.address ?? ""
                let addressType = try? addressFactory.extractAddressType(from: address)
                let accountId = try? addressFactory.accountId(fromAddress: address, type: addressType ?? 0)
                let referrer = accountId?.toHex(includePrefix: true) ?? ""
                
                let call = try callFactory.setReferrer(referrer: referrer)
                return try builder.adding(call: call)
            }
        case .reward, .incoming, .migration, .extrinsic, .slash, .demeterDeposit, .demeterWithdraw, .demeterClaimReward:
            ()
        }
        
        guard let builderClosure else { return Decimal(0) }
        return await estimateFee(for: type.rawValue, builderClosure: builderClosure, runningIn: .main)
    }

    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
        if let cached = feeStore[type.rawValue] {
            completion(cached)
            return
        }

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let call = try type == .bond ? callFactory.reserveReferralBalance(balance: 0) : callFactory.unreserveReferralBalance(balance: 0)
            return try builder.adding(call: call)
        }
        
        estimateFee(for: type.rawValue, builderClosure: builderClosure, runningIn: .main, completion: completion)
    }
    
    func getFee(for call: any RuntimeCallable) async -> Decimal {
        let builderClosure: ExtrinsicBuilderClosure = { builder in
            return try builder.adding(call: call)
        }
        
        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(builderClosure, runningIn: .main, completion: { result in
                switch result {
                case let .success(info):
                    guard let fee = BigUInt(info), let decimalFee = Decimal.fromSubstrateAmount(fee, precision: 18) else { return }
                    continuation.resume(returning: decimalFee)
                case let .failure(error):
                    print("fee error: \(error)")
                }
            })
        }
    }
    
    @available(*, renamed: "estimateFee(for:builderClosure:runningIn:)")
    private func estimateFee(
        for type: String,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping (Decimal) -> Void
    ) {
        Task {
            let result = await estimateFee(for: type, builderClosure: builderClosure, runningIn: queue)
            completionClosure(result)
        }
    }

    private func estimateFee(
        for type: String,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue) async -> Decimal {
            return await withCheckedContinuation { continuation in
                extrinsicService.estimateFee(builderClosure, runningIn: queue, completion: { [weak self] result in
                    switch result {
                    case let .success(info):
                        guard let fee = BigUInt(info), let decimalFee = Decimal.fromSubstrateAmount(fee, precision: 18) else { return }
                        self?.feeStore[type] = decimalFee
                        continuation.resume(returning: decimalFee)
                    case let .failure(error):
                        print("fee error: \(error)")
                    }
                })
            }
        }
}
