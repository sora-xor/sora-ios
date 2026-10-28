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

    private let boundAccount: AccountItem?

    private var selectedAccount: AccountItem? {
        boundAccount
    }

    private var extrinsicService: ExtrinsicService? {
        guard let selectedAccount,
              let engine = ChainRegistryFacade.sharedRegistry.getConnection(
                for: Chain.sora.genesisHash()
              ),
              let runtime = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(
                for: Chain.sora.genesisHash()
              ) else {
            return nil
        }
        return ExtrinsicService(address: selectedAccount.address,
                                cryptoType: selectedAccount.cryptoType,
                                runtimeRegistry: runtime,
                                engine: engine,
                                operationManager: OperationManagerFacade.sharedManager)
    }

    init(account: AccountItem? = SelectedWalletSettings.shared.currentAccount) {
        boundAccount = account
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
                    .adding(call: initializeCall)
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
        return await estimateFee(builderClosure: builderClosure, runningIn: .main)
    }

    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()
            let call = try type == .bond ? callFactory.reserveReferralBalance(balance: 0) : callFactory.unreserveReferralBalance(balance: 0)
            return try builder.adding(call: call)
        }
        
        estimateFee(builderClosure: builderClosure, runningIn: .main, completion: completion)
    }
    
    func getFee(for call: any RuntimeCallable) async -> Decimal {
        guard let extrinsicService else {
            return .zero
        }
        let builderClosure: ExtrinsicBuilderClosure = { builder in
            return try builder.adding(call: call)
        }
        
        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(builderClosure, runningIn: .main, completion: { result in
                switch result {
                case let .success(info):
                    guard let fee = BigUInt(info), let decimalFee = Decimal.fromSubstrateAmount(fee, precision: 18) else {
                        continuation.resume(returning: .zero)
                        return
                    }
                    continuation.resume(returning: decimalFee)
                case .failure:
                    print("Fee calculation failed")
                    continuation.resume(returning: .zero)
                }
            })
        }
    }
    
    @available(*, renamed: "estimateFee(builderClosure:runningIn:)")
    private func estimateFee(
        builderClosure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping (Decimal) -> Void
    ) {
        Task {
            let result = await estimateFee(builderClosure: builderClosure, runningIn: queue)
            completionClosure(result)
        }
    }

    private func estimateFee(
        builderClosure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue) async -> Decimal {
            guard let extrinsicService else {
                return .zero
            }
            return await withCheckedContinuation { continuation in
                extrinsicService.estimateFee(builderClosure, runningIn: queue, completion: { result in
                    switch result {
                    case let .success(info):
                        guard let fee = BigUInt(info), let decimalFee = Decimal.fromSubstrateAmount(fee, precision: 18) else {
                            continuation.resume(returning: .zero)
                            return
                        }
                        continuation.resume(returning: decimalFee)
                    case .failure:
                        print("Fee calculation failed")
                        continuation.resume(returning: .zero)
                    }
                })
            }
        }
}
