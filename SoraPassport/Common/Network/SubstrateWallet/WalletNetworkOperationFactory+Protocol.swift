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

import BigInt

import SSFUtils
import Foundation
import IrohaCrypto
import RobinHood
import Starscream
import xxHash_Swift

enum WalletNetworkOperationFactoryError: Error {
    case invalidAmount
    case invalidAsset
    case invalidChain
    case invalidReceiver
    case invalidContext
    case invalidFee
    case insufficientBalance
}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func getPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        CompoundOperationWrapper(targetOperation: .init())
    }

    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        return CompoundOperationWrapper<[BalanceData]?>.createWithResult(nil)
    }

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let operation = ClosureOperation<AssetTransactionPageData?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        guard let asset = accountSettings.assets.first(where: { $0.identifier == info.assetId }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return createCompoundOperation(result: .failure(error))
        }

        let chain = asset.chain

        guard let amount = Decimal(1.0).toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return createCompoundOperation(result: .failure(error))
        }

        guard let receiver = try? Data(hexStringSSF: info.receiver) else {
            let error = WalletNetworkOperationFactoryError.invalidReceiver
            return createCompoundOperation(result: .failure(error))
        }

        let feeAsset = accountSettings.assets.first(where: { $0.isFeeAsset }) ?? asset

        let compoundReceiver = createAccountInfoFetchOperation(receiver)

        let feeOperation = createExtrinsicFeeServiceOperation(asset: asset.identifier,
                                                              amount: amount,
                                                              receiver: info.receiver,
                                                              chain: chain)

        let mapOperation: ClosureOperation<TransferMetaData?> = ClosureOperation {
            let fee = try feeOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            
            guard let bigIntFee = BigUInt(fee) else {
                return nil
            }

            let decimalFee = Decimal.fromSubstrateAmount(bigIntFee, precision: feeAsset.precision) ?? 0

            let amount = AmountDecimal(value: decimalFee)

            let feeDescription = FeeDescription(identifier: feeAsset.identifier,
                                                assetId: feeAsset.identifier,
                                                type: FeeType.fixed.rawValue,
                                                parameters: [amount])

            if let receiverInfo = try compoundReceiver.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {
                let context = TransferMetadataContext(data: receiverInfo.data,
                                                      precision: asset.precision).toContext()
                return TransferMetaData(feeDescriptions: [feeDescription], context: context)
            } else {
                return TransferMetaData(feeDescriptions: [feeDescription])
            }
        }

        let dependencies = [feeOperation] /* + compoundInfo.allOperations */ + compoundReceiver.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            try Sora2LegacyTransferAdmission.requirePreparedPath(for: info.type)
        } catch {
            return createCompoundOperation(result: .failure(error))
        }
        switch info.type {
        case .swap:
            return swapOperationWrapper(info)
        case .liquidityAdd,
             .liquidityAddNewPool,
             .liquidityAddToExistingPoolFirstTime,
             .liquidityRemoval:
            return liquidityOperationWrapper(info)
        case .demeterClaimReward:
            return claimRewardDemeterOperationWrapper(info)
        case .demeterDeposit:
            return depositDemeterOperationWrapper(info)
        case .demeterWithdraw:
            return withdrawDemeterOperationWrapper(info)
        case .outgoing:
            return createCompoundOperation(
                result: .failure(WalletNetworkOperationFactoryError.invalidContext)
            )
        case .incoming, .slash, .reward, .extrinsic, .referral, .migration:
            return transferOperationWrapper(info)
        }
    }

    func estimateTransferFee(for info: TransferInfo) async throws -> Decimal {
        try Task.checkCancellation()
        guard info.type == .outgoing else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        let closure = try exactTransferBuilderClosure(for: info)
        let service = extrinsicService
        let rawFee: String = try await withCheckedThrowingContinuation {
            continuation in
            service.estimateFee(closure, runningIn: .main) { result in
                continuation.resume(with: result)
            }
        }

        try Task.checkCancellation()
        let feeAssets = accountSettings.assets.filter {
            $0.identifier == WalletAssetId.xor.rawValue && $0.isFeeAsset
        }
        guard feeAssets.count == 1,
              let feeAsset = feeAssets.first,
              let feeValue = BigUInt(rawFee),
              feeValue > 0,
              let exactFee = Decimal.fromSubstrateAmount(
                  feeValue,
                  precision: feeAsset.precision
              ),
              exactFee > 0 else {
            throw WalletNetworkOperationFactoryError.invalidFee
        }
        return exactFee
    }

    func prepareTransferSubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedSora2TransferSubmission {
        try Task.checkCancellation()
        guard info.type == .outgoing else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        let closure = try exactTransferBuilderClosure(for: info)
        let feeAssets = accountSettings.assets.filter {
            $0.identifier == WalletAssetId.xor.rawValue && $0.isFeeAsset
        }
        guard feeAssets.count == 1, let feeAsset = feeAssets.first else {
            throw WalletNetworkOperationFactoryError.invalidFee
        }

        let service = extrinsicService
        let signer = accountSigner
        let cancellable = CancellableCallRelay()
        let qualification: PreparedExtrinsicFeeQualification = try await
            withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { continuation in
                    let call = service.prepareAndEstimateFee(
                        closure,
                        signer: signer,
                        preSigningValidation: preSigningValidation,
                        runningIn: .main
                    ) { result in
                        continuation.resume(with: result)
                    }
                    cancellable.set(call)
                }
            }, onCancel: {
                cancellable.cancel()
            })

        do {
            try Task.checkCancellation()
            guard let feeValue = BigUInt(qualification.rawFee),
                  feeValue > 0,
                  let exactFee = Decimal.fromSubstrateAmount(
                      feeValue,
                      precision: feeAsset.precision
                  ),
                  exactFee > 0 else {
                throw WalletNetworkOperationFactoryError.invalidFee
            }
            return PreparedSora2TransferSubmission(
                fee: exactFee,
                rawFee: qualification.rawFee,
                preparedExtrinsic: qualification.prepared
            )
        } catch {
            qualification.prepared.discard()
            throw error
        }
    }

    func submitPreparedTransfer(
        _ submission: PreparedSora2TransferSubmission,
        info _: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        do {
            try Task.checkCancellation()
        } catch {
            submission.discard()
            throw PreparedExtrinsicTransportError.failedBeforeTransport(error)
        }
        guard let signer = accountSigner as? LifecycleSigningWrapperProtocol else {
            submission.discard()
            throw PreparedExtrinsicTransportError.failedBeforeTransport(
                ExtrinsicServiceError.lifecycleSignerRequired
            )
        }
        let boundAccount = signer.signingAccount
        let service = extrinsicService
        let cancellable = CancellableCallRelay()
        let returnedHash: String = try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation {
                    continuation in
                    let call = service.submitPrepared(
                        submission.preparedExtrinsic,
                        retainingTransportWitness: false,
                        expectedRawFee: submission.rawFee,
                        preTransportValidation: {
                            try preTransportValidation()
                            guard
                                let selected = SelectedWalletSettings.shared
                                    .currentAccount,
                                selected.isSelected,
                                selected.address == boundAccount.address,
                                selected.publicKeyData ==
                                    boundAccount.publicKeyData,
                                selected.cryptoType == boundAccount.cryptoType,
                                selected.networkType == boundAccount.networkType
                            else {
                                throw SigningWrapperError
                                    .missingSelectedAccount
                            }
                        },
                        runningIn: .main
                    ) { result in
                        continuation.resume(with: result)
                    }
                    cancellable.set(call)
                }
            },
            onCancel: {
                cancellable.cancel()
            }
        )
        guard
            Sora2PendingSubmissionStore.normalizedHash(returnedHash) ==
                Sora2PendingSubmissionStore.normalizedHash(
                    submission.transactionHash
                )
        else {
            throw PreparedExtrinsicTransportError.submissionUnknown(
                localHash:
                    Sora2PendingSubmissionStore.normalizedHash(
                        submission.transactionHash
                    ) ?? submission.transactionHash,
                error: ExtrinsicServiceError.invalidLocalHash
            )
        }
        return try Data(hexStringSSF: returnedHash)
    }

    func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal {
        try Task.checkCancellation()
        let closure = try exactLiquidityBuilderClosure(for: info)
        let service = extrinsicService
        let rawFee: String = try await withCheckedThrowingContinuation { continuation in
            service.estimateFee(closure, runningIn: .main) { result in
                continuation.resume(with: result)
            }
        }

        try Task.checkCancellation()
        let feeAssets = accountSettings.assets.filter {
            $0.identifier == WalletAssetId.xor.rawValue && $0.isFeeAsset
        }
        guard feeAssets.count == 1,
              let feeAsset = feeAssets.first,
              let feeValue = BigUInt(rawFee),
              let exactFee = Decimal.fromSubstrateAmount(feeValue, precision: feeAsset.precision),
              exactFee > 0 else {
            throw WalletNetworkOperationFactoryError.invalidFee
        }
        return exactFee
    }

    func prepareLiquiditySubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedLiquiditySubmission {
        try Task.checkCancellation()
        let closure = try exactLiquidityBuilderClosure(for: info)
        let feeAssets = accountSettings.assets.filter {
            $0.identifier == WalletAssetId.xor.rawValue && $0.isFeeAsset
        }
        guard feeAssets.count == 1, let feeAsset = feeAssets.first else {
            throw WalletNetworkOperationFactoryError.invalidFee
        }

        let service = extrinsicService
        let signer = accountSigner
        let cancellable = CancellableCallRelay()
        let qualification: PreparedExtrinsicFeeQualification = try await
            withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { continuation in
                    let call = service.prepareAndEstimateFee(
                        closure,
                        signer: signer,
                        preSigningValidation: preSigningValidation,
                        runningIn: .main
                    ) { result in
                        continuation.resume(with: result)
                    }
                    cancellable.set(call)
                }
            }, onCancel: {
                cancellable.cancel()
            })

        do {
            try Task.checkCancellation()
            guard let feeValue = BigUInt(qualification.rawFee),
                  feeValue > 0,
                  let exactFee = Decimal.fromSubstrateAmount(
                    feeValue,
                    precision: feeAsset.precision
                  ),
                  exactFee > 0 else {
                throw WalletNetworkOperationFactoryError.invalidFee
            }
            return PreparedLiquiditySubmission(
                fee: exactFee,
                rawFee: qualification.rawFee,
                preparedExtrinsic: qualification.prepared
            )
        } catch {
            qualification.prepared.discard()
            throw error
        }
    }

    func submitPreparedLiquidity(
        _ submission: PreparedLiquiditySubmission,
        info _: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        do {
            try Task.checkCancellation()
        } catch {
            submission.discard()
            throw PreparedExtrinsicTransportError.failedBeforeTransport(error)
        }
        guard let signer = accountSigner as? LifecycleSigningWrapperProtocol else {
            submission.discard()
            throw PreparedExtrinsicTransportError.failedBeforeTransport(
                ExtrinsicServiceError.lifecycleSignerRequired
            )
        }
        let boundAccount = signer.signingAccount
        let service = extrinsicService
        let cancellable = CancellableCallRelay()
        let returnedHash: String = try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation {
                    continuation in
                    let call = service.submitPrepared(
                        submission.preparedExtrinsic,
                        retainingTransportWitness: false,
                        expectedRawFee: submission.rawFee,
                        preTransportValidation: {
                            try preTransportValidation()
                            guard
                                let selected =
                                    SelectedWalletSettings.shared
                                        .currentAccount,
                                selected.isSelected,
                                selected.address == boundAccount.address,
                                selected.publicKeyData ==
                                    boundAccount.publicKeyData,
                                selected.cryptoType == boundAccount.cryptoType,
                                selected.networkType ==
                                    boundAccount.networkType
                            else {
                                throw SigningWrapperError
                                    .missingSelectedAccount
                            }
                        },
                        runningIn: .main
                    ) { result in
                        continuation.resume(with: result)
                    }
                    cancellable.set(call)
                }
            },
            onCancel: {
                cancellable.cancel()
            }
        )
        guard
            Sora2PendingSubmissionStore.normalizedHash(returnedHash) ==
                Sora2PendingSubmissionStore.normalizedHash(
                    submission.transactionHash
                )
        else {
            throw PreparedExtrinsicTransportError.submissionUnknown(
                localHash:
                    Sora2PendingSubmissionStore.normalizedHash(
                        submission.transactionHash
                    ) ?? submission.transactionHash,
                error: ExtrinsicServiceError.invalidLocalHash
            )
        }
        return try Data(hexStringSSF: returnedHash)
    }

    private func liquidityOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            let closure = try exactLiquidityBuilderClosure(for: info)
            let operation = createExtrinsicServiceOperation(closure: closure)
            let mapOperation: ClosureOperation<Data> = ClosureOperation {
                let hashString = try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return try Data(hexStringSSF: hashString)
            }
            mapOperation.addDependency(operation)
            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
        } catch {
            return createCompoundOperation(result: .failure(error))
        }
    }

    /// The sole liquidity call constructor used by both fee qualification and
    /// submission. Keeping parsing, rounding, and batch order here prevents a
    /// reviewed fee from describing a different extrinsic shape.
    private func exactLiquidityBuilderClosure(for info: TransferInfo) throws -> ExtrinsicBuilderClosure {
        guard info.source != info.destination,
              let assetA = accountSettings.assets.first(where: { $0.identifier == info.source }),
              let assetB = accountSettings.assets.first(where: { $0.identifier == info.destination }) else {
            throw WalletNetworkOperationFactoryError.invalidAsset
        }

        switch info.type {
        case .liquidityAdd, .liquidityAddToExistingPoolFirstTime, .liquidityAddNewPool:
            guard let context = info.context,
                  let rawDesiredA = context[TransactionContextKeys.firstAssetAmount],
                  let rawDesiredB = context[TransactionContextKeys.secondAssetAmount],
                  let desiredA = AmountDecimal(string: rawDesiredA)?.decimalValue,
                  let desiredB = AmountDecimal(string: rawDesiredB)?.decimalValue,
                  let rawSlippage = context[TransactionContextKeys.slippage],
                  let slippage = PolkaswapSlippage(contextValue: rawSlippage),
                  let dexId = context[TransactionContextKeys.dex] else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }

            let minA = slippage.minimumAmount(for: desiredA)
            let minB = slippage.minimumAmount(for: desiredB)
            guard desiredA > 0,
                  desiredB > 0,
                  let amountA = desiredA.toSubstrateAmount(precision: assetA.precision),
                  let amountB = desiredB.toSubstrateAmount(precision: assetB.precision),
                  let amountMinA = minA.toSubstrateAmountRoundingDown(precision: assetA.precision),
                  let amountMinB = minB.toSubstrateAmountRoundingDown(precision: assetB.precision),
                  amountA > 0,
                  amountB > 0,
                  amountMinA > 0,
                  amountMinB > 0 else {
                throw WalletNetworkOperationFactoryError.invalidAmount
            }

            let transactionType = info.type
            return { builder in
                let callFactory = SubstrateCallFactory()
                let depositCall = try callFactory.depositLiquidity(
                    dexId: dexId,
                    assetA: assetA.identifier,
                    assetB: assetB.identifier,
                    desiredA: amountA,
                    desiredB: amountB,
                    minA: amountMinA,
                    minB: amountMinB
                )

                switch transactionType {
                case .liquidityAdd:
                    return try builder.adding(call: depositCall)
                case .liquidityAddToExistingPoolFirstTime:
                    let initializeCall = try callFactory.initializePool(
                        dexId: dexId,
                        baseAssetId: assetA.identifier,
                        targetAssetId: assetB.identifier
                    )
                    return try builder
                        .with(shouldUseAtomicBatch: true)
                        .adding(call: initializeCall)
                        .adding(call: depositCall)
                case .liquidityAddNewPool:
                    let registerCall = try callFactory.register(
                        dexId: dexId,
                        baseAssetId: assetA.identifier,
                        targetAssetId: assetB.identifier
                    )
                    let initializeCall = try callFactory.initializePool(
                        dexId: dexId,
                        baseAssetId: assetA.identifier,
                        targetAssetId: assetB.identifier
                    )
                    return try builder
                        .with(shouldUseAtomicBatch: true)
                        .adding(call: registerCall)
                        .adding(call: initializeCall)
                        .adding(call: depositCall)
                default:
                    throw WalletNetworkOperationFactoryError.invalidContext
                }
            }

        case .liquidityRemoval:
            guard let context = info.context,
                  let dexId = context[TransactionContextKeys.dex],
                  let rawDesiredA = context[TransactionContextKeys.firstAssetAmount],
                  let rawDesiredB = context[TransactionContextKeys.secondAssetAmount],
                  let desiredA = Decimal(string: rawDesiredA, locale: Locale(identifier: "en_US_POSIX")),
                  let desiredB = Decimal(string: rawDesiredB, locale: Locale(identifier: "en_US_POSIX")),
                  let rawFirstReserves = context[TransactionContextKeys.firstReserves],
                  let firstReserves = Decimal(
                    string: rawFirstReserves,
                    locale: Locale(identifier: "en_US_POSIX")
                  ),
                  let rawTotalIssuances = context[TransactionContextKeys.totalIssuances],
                  let totalIssuances = Decimal(
                    string: rawTotalIssuances,
                    locale: Locale(identifier: "en_US_POSIX")
                  ),
                  let rawSlippage = context[TransactionContextKeys.slippage],
                  let slippage = PolkaswapSlippage(contextValue: rawSlippage) else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }

            guard desiredA > 0,
                  desiredB > 0,
                  firstReserves > 0,
                  totalIssuances > 0 else {
                throw WalletNetworkOperationFactoryError.invalidAmount
            }

            let desiredPoolTokens = desiredA / firstReserves * totalIssuances
            let minA = slippage.minimumAmount(for: desiredA)
            let minB = slippage.minimumAmount(for: desiredB)
            guard
                  let assetDesired = desiredPoolTokens.toSubstrateAmount(precision: assetA.precision),
                  let amountMinA = minA.toSubstrateAmountRoundingDown(precision: assetA.precision),
                  let amountMinB = minB.toSubstrateAmountRoundingDown(precision: assetB.precision),
                  assetDesired > 0,
                  amountMinA > 0,
                  amountMinB > 0 else {
                throw WalletNetworkOperationFactoryError.invalidAmount
            }

            return { builder in
                let call = try SubstrateCallFactory().withdrawLiquidityCall(
                    dexId: dexId,
                    assetA: assetA.identifier,
                    assetB: assetB.identifier,
                    assetDesired: assetDesired,
                    minA: amountMinA,
                    minB: amountMinB
                )
                return try builder.adding(call: call)
            }

        default:
            throw WalletNetworkOperationFactoryError.invalidContext
        }
    }

    private func transferOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            let closure = try exactTransferBuilderClosure(for: info)
            let transferOperation = createExtrinsicServiceOperation(
                closure: closure
            )
            let mapOperation: ClosureOperation<Data> = ClosureOperation {
                let hashString = try Sora2LegacySubmissionProjection
                    .transactionHash(from: transferOperation.result)
                return try Data(hexStringSSF: hashString)
            }
            mapOperation.addDependency(transferOperation)
            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [transferOperation]
            )
        } catch {
            return createCompoundOperation(result: .failure(error))
        }
    }

    /// The only ordinary-transfer call constructor. Preview, exact signed fee
    /// qualification, history projection, and transport all retain this shape.
    private func exactTransferBuilderClosure(
        for info: TransferInfo
    ) throws -> ExtrinsicBuilderClosure {
        guard !info.destination.isEmpty,
              let asset = accountSettings.assets.first(where: {
                  $0.identifier == info.asset
              }) else {
            throw WalletNetworkOperationFactoryError.invalidAsset
        }
        guard info.amount.decimalValue > 0,
              let amount = info.amount.decimalValue.toSubstrateAmount(
                  precision: asset.precision
              ),
              amount > 0 else {
            throw WalletNetworkOperationFactoryError.invalidAmount
        }

        return { builder in
            let transferCall = try SubstrateCallFactory().transfer(
                to: info.destination,
                asset: asset.identifier,
                amount: amount
            )
            return try builder.adding(call: transferCall)
        }
    }

    private func swapOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard info.asset != info.destination,
            let asset = accountSettings.assets.first(where: { $0.identifier == info.asset }),
            accountSettings.assets.first(where: { $0.identifier == info.destination }) != nil
        else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return createCompoundOperation(result: .failure(error))
        }

        guard let context = info.context else {
            let error = WalletNetworkOperationFactoryError.invalidContext
            return createCompoundOperation(result: .failure(error))
        }

        guard let amountCall = info.amountCall else {
            let error = WalletNetworkOperationFactoryError.invalidContext
            return createCompoundOperation(result: .failure(error))
        }

        guard let sourceType = context[TransactionContextKeys.marketType],
              let marketType = LiquiditySourceType(rawValue: sourceType),
              let dexId = context[TransactionContextKeys.dex] else {
            return createCompoundOperation(result: .failure(WalletNetworkOperationFactoryError.invalidContext))
        }
        let marketCode = marketType.code
        let filter = marketType.filter

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let call = try SubstrateCallFactory().swap(
                from: asset.identifier,
                to: info.destination,
                dexId: dexId,
                amountCall: amountCall,
                type: marketCode,
                filter: filter
            )
            return try builder.adding(call: call)
        }

        let wrapper = createExtrinsicServiceOperation(closure: builderClosure)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try wrapper
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexStringSSF: hashString)
        }

        mapOperation.addDependency(wrapper)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: [wrapper])
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        return CompoundOperationWrapper<[SearchData]?>.createWithResult(nil)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        return CompoundOperationWrapper<[SearchData]?>.createWithResult(nil)
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?> {
        return CompoundOperationWrapper<WithdrawMetaData?>.createWithResult(nil)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        return CompoundOperationWrapper<Data>.createWithResult(Data())
    }
    
    private func claimRewardDemeterOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard let demeterContext = validatedDemeterContext(info) else {
            return createCompoundOperation(result: .failure(WalletNetworkOperationFactoryError.invalidContext))
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let demeterCall = try callFactory.claimRewardFromDemeterFarmCall(
                baseAssetId: info.source,
                targetAssetId: info.destination,
                rewardAssetId: demeterContext.rewardAsset,
                isFarm: demeterContext.isFarm
            )

            return try builder.adding(call: demeterCall)
        }

        let transferOperation = createExtrinsicServiceOperation(closure: closure)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexStringSSF: hashString)
        }

        mapOperation.addDependency(transferOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [transferOperation])
    }
    
    private func depositDemeterOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard info.amount.decimalValue > 0,
              let amount = info.amount.decimalValue.toSubstrateAmount(precision: 18),
              amount > 0 else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return createCompoundOperation(result: .failure(error))
        }

        guard let demeterContext = validatedDemeterContext(info) else {
            return createCompoundOperation(result: .failure(WalletNetworkOperationFactoryError.invalidContext))
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let demeterCall = try callFactory.depositLiquidityToDemeterFarmCall(
                baseAssetId: info.source,
                targetAssetId: info.destination,
                rewardAssetId: demeterContext.rewardAsset,
                isFarm: demeterContext.isFarm,
                amount: amount
            )

            return try builder.adding(call: demeterCall)
        }

        let transferOperation = createExtrinsicServiceOperation(closure: closure)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexStringSSF: hashString)
        }

        mapOperation.addDependency(transferOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [transferOperation])
    }
    
    private func withdrawDemeterOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard info.amount.decimalValue > 0,
              let amount = info.amount.decimalValue.toSubstrateAmount(precision: 18),
              amount > 0 else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return createCompoundOperation(result: .failure(error))
        }

        guard let demeterContext = validatedDemeterContext(info) else {
            return createCompoundOperation(result: .failure(WalletNetworkOperationFactoryError.invalidContext))
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let demeterCall = try callFactory.withdrawLiquidityFromDemeterFarmCall(
                baseAssetId: info.source,
                targetAssetId: info.destination,
                rewardAssetId: demeterContext.rewardAsset,
                isFarm: demeterContext.isFarm,
                amount: amount
            )

            return try builder.adding(call: demeterCall)
        }

        let transferOperation = createExtrinsicServiceOperation(closure: closure)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexStringSSF: hashString)
        }

        mapOperation.addDependency(transferOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [transferOperation])
    }

    private func validatedDemeterContext(
        _ info: TransferInfo
    ) -> (rewardAsset: String, isFarm: Bool)? {
        guard !info.source.isEmpty,
              !info.destination.isEmpty,
              let context = info.context,
              let rewardAsset = context[TransactionContextKeys.rewardAsset],
              !rewardAsset.isEmpty,
              let rawIsFarm = context[TransactionContextKeys.isFarm],
              rawIsFarm == "0" || rawIsFarm == "1" else {
            return nil
        }
        return (rewardAsset, rawIsFarm == "1")
    }
}
