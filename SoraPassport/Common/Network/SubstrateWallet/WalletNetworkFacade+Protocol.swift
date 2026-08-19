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
import SoraKeystore

extension WalletNetworkFacade: WalletNetworkOperationFactoryProtocol {

    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        return fetchBalanceOperation(assets, onlyVisible: true)
    }

    func fetchBalanceOperation(_ assets: [String], onlyVisible: Bool) -> CompoundOperationWrapper<[BalanceData]?> {
        let userAssets: [WalletAsset] = assets.compactMap { identifier in
            guard identifier != totalPriceAssetId?.rawValue else {
                return nil
            }

            return accountSettings.assets.first { $0.identifier == identifier }
        }
        // hack while Capital can't change order

        let sortedAssets = assetManager.sortedAssets(userAssets, onlyVisible: onlyVisible)

        let balanceOperation = fetchBalanceInfoForAssets(sortedAssets)

        return balanceOperation
    }

    func fetchTransactionHistoryOperation(
        _ request: WalletHistoryRequest,
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let filter = WalletHistoryFilter(string: request.filter)

        let historyContext = TransactionHistoryContext(context: pagination.context ?? [:])

        guard !historyContext.isComplete,
              let feeAsset = accountSettings.assets.first(where: { $0.isFeeAsset }),
              WalletAssetId(rawValue: feeAsset.identifier) != nil
        else {
            let pageData = AssetTransactionPageData(
                transactions: [],
                context: nil
            )

            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let remoteHistoryWrapper: CompoundOperationWrapper<WalletRemoteHistoryData>

        let remoteHistoryFactory = SubqueryHistoryOperationFactory(
            url: ConfigService.shared.config.subqueryURL,
            filter: filter
        )

        remoteHistoryWrapper = remoteHistoryFactory.createOperationWrapper(
            for: historyContext,
            address: address,
            count: pagination.count
        )

        var dependencies = remoteHistoryWrapper.allOperations

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?
        let pendingFetchOperation: BaseOperation<[Sora2PendingSubmission]>?

        if pagination.context == nil {
            let operation = txStorage.fetchAllOperation(with: RepositoryFetchOptions())
            let pendingOperation: BaseOperation<[Sora2PendingSubmission]> =
                ClosureOperation {
                    try Sora2PendingSubmissionStore().all()
                }
            dependencies.append(operation)
            dependencies.append(pendingOperation)

            remoteHistoryWrapper.allOperations.forEach { operation.addDependency($0) }

            localFetchOperation = operation
            pendingFetchOperation = pendingOperation
        } else {
            localFetchOperation = nil
            pendingFetchOperation = nil
        }

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper.targetOperation,
            localOperation: localFetchOperation,
            pendingOperation: pendingFetchOperation,
            feeAsset: feeAsset,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }

        dependencies.append(mergeOperation)

        if pagination.context == nil {
            let clearOperation = txStorage.saveOperation({ [] }, {
                let mergeResult = try mergeOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return mergeResult.identifiersToRemove
            })

            dependencies.append(clearOperation)
            clearOperation.addDependency(mergeOperation)
        }

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryWrapper.targetOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo)
        -> CompoundOperationWrapper<TransferMetaData?> {
        nodeOperationFactory.transferMetadataOperation(info)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            try Sora2LegacyTransferAdmission.requirePreparedPath(for: info.type)
            let currentNetworkType = networkType
            let addressFactory = SS58AddressFactory()
            let contactSaveWrapper: CompoundOperationWrapper<Void> =
                .createWithResult(())

            let transferWrapper: CompoundOperationWrapper = nodeOperationFactory.transferOperation(info)
            let sourceAssetPrecision = accountSettings.assets.first(
                where: { $0.identifier == info.asset }
            )?.precision ?? 18
            let destinationAssetPrecision = accountSettings.assets.first(
                where: { $0.identifier == info.destination }
            )?.precision ?? 18

            let txSaveOperation = txStorage.saveOperation({
                let txHash = try Sora2LegacySubmissionProjection
                    .transactionHash(
                        from: transferWrapper.targetOperation.result
                    )
                let item = try TransactionHistoryItem.createFromTransferInfo(
                    info,
                    transactionHash: txHash,
                    senderAddress: self.address,
                    networkType: currentNetworkType,
                    addressFactory: addressFactory,
                    sourceAssetPrecision: sourceAssetPrecision,
                    destinationAssetPrecision: destinationAssetPrecision
                )
                return [item]
            }, { [] })

            transferWrapper.allOperations.forEach { transaferOperation in
                txSaveOperation.addDependency(transaferOperation)

                contactSaveWrapper.allOperations.forEach { $0.addDependency(transaferOperation) }
            }

            let completionOperation: BaseOperation<Data> = ClosureOperation {
                try Sora2LegacySubmissionProjection.transactionHash(
                    from: transferWrapper.targetOperation.result
                )
            }

            let dependencies = [txSaveOperation] + contactSaveWrapper.allOperations + transferWrapper.allOperations

            // Local history/contact persistence is best-effort after a
            // successful transport result. It must never rewrite an accepted
            // transaction as failed and pressure the user into retrying it.
            completionOperation.addDependency(transferWrapper.targetOperation)

            return CompoundOperationWrapper(targetOperation: completionOperation,
                                            dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func estimateTransferFee(for info: TransferInfo) async throws -> Decimal {
        try await nodeOperationFactory.estimateTransferFee(for: info)
    }

    func prepareTransferSubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedSora2TransferSubmission {
        try await nodeOperationFactory.prepareTransferSubmission(
            for: info,
            preSigningValidation: preSigningValidation
        )
    }

    func submitPreparedTransfer(
        _ submission: PreparedSora2TransferSubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        guard let transactionHash = try? Data(
            hexStringSSF: submission.transactionHash
        ) else {
            submission.discard()
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        let pending = try TransactionHistoryItem.createFromTransferInfo(
            info,
            transactionHash: transactionHash,
            senderAddress: address,
            networkType: networkType,
            addressFactory: SS58AddressFactory()
        )

        // Persist the exact local hash and reviewed exact fee before any RPC
        // transport. Restart reconciliation therefore never needs to rebuild or
        // infer a different ordinary transfer.
        try await performLocalHistorySave(
            updates: [pending],
            deletes: []
        )

        do {
            return try await nodeOperationFactory.submitPreparedTransfer(
                submission,
                info: info,
                preTransportValidation: preTransportValidation
            )
        } catch let error as PreparedExtrinsicTransportError {
            if case .failedBeforeTransport = error {
                try? await performLocalHistorySave(
                    updates: [],
                    deletes: [pending.identifier]
                )
            }
            throw error
        } catch {
            throw PreparedExtrinsicTransportError.submissionUnknown(
                localHash:
                    Sora2PendingSubmissionStore.normalizedHash(
                        submission.transactionHash
                    ) ?? submission.transactionHash,
                error: error
            )
        }
    }

    func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal {
        try await nodeOperationFactory.estimateLiquidityFee(for: info)
    }

    func prepareLiquiditySubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedLiquiditySubmission {
        try await nodeOperationFactory.prepareLiquiditySubmission(
            for: info,
            preSigningValidation: preSigningValidation
        )
    }

    func submitPreparedLiquidity(
        _ submission: PreparedLiquiditySubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        guard
            let call = submission.preparedExtrinsic.call,
            let transactionHash = try? Data(
                hexStringSSF: submission.transactionHash
            )
        else {
            submission.discard()
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        let pending = try TransactionHistoryItem
            .createFromPreparedLiquidity(
                info,
                transactionHash: transactionHash,
                senderAddress: address,
                rawFee: submission.rawFee,
                exactCall: call
            )

        // The exact-call overlay is durable before transport. A crash or an
        // ambiguous RPC result therefore cannot make the transaction vanish
        // or encourage rebuilding/retrying different signed bytes.
        try await performLocalHistorySave(
            updates: [pending],
            deletes: []
        )

        do {
            return try await nodeOperationFactory.submitPreparedLiquidity(
                submission,
                info: info,
                preTransportValidation: preTransportValidation
            )
        } catch let error as PreparedExtrinsicTransportError {
            if case .failedBeforeTransport = error {
                // Removal is best effort: a stale local pending row is safer
                // than deleting an ambiguously submitted transaction.
                try? await performLocalHistorySave(
                    updates: [],
                    deletes: [pending.identifier]
                )
            }
            throw error
        } catch {
            // Unknown error classes after the one-shot handoff are retained as
            // pending and reconciled. Never infer that transport did not run.
            throw PreparedExtrinsicTransportError.submissionUnknown(
                localHash:
                    Sora2PendingSubmissionStore.normalizedHash(
                        submission.transactionHash
                    ) ?? submission.transactionHash,
                error: error
            )
        }
    }

    private func performLocalHistorySave(
        updates: [TransactionHistoryItem],
        deletes: [String]
    ) async throws {
        let operation = txStorage.saveOperation(
            { updates },
            { deletes }
        )
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                operation.completionBlock = {
                    continuation.resume(
                        with: operation.result ??
                            .failure(
                                BaseOperationError.parentOperationCancelled
                            )
                    )
                }
                OperationManagerFacade.sharedDefaultQueue.addOperation(
                    operation
                )
            }
        }, onCancel: {
            operation.cancel()
        })
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        let fetchOperation = contactsOperation()

        let normalizedSearch = searchString.lowercased()

        let filterOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let result = try fetchOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return result?.filter {
                ($0.firstName.lowercased().range(of: normalizedSearch) != nil) ||
                    ($0.lastName.lowercased().range(of: normalizedSearch) != nil)
            }
        }

        let dependencies = fetchOperation.allOperations
        dependencies.forEach { filterOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: filterOperation,
                                        dependencies: dependencies)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        let currentNetworkType = networkType

        let accountsOperation = accountsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let contactsOperation = contactsOperationFactory.fetchContactsOperation()
        let mapOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let accounts = try accountsOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let existingAddresses = Set<String>(
                accounts.map { $0.address }
            )

            let addressFactory = SS58AddressFactory()

            let accountsResult = try accounts.map {
                try SearchData.createFromAccountItem($0,
                                                     addressFactory: addressFactory)
            }

            let contacts = try contactsOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .filter({ !existingAddresses.contains($0.peerAddress) })

            let contactsResult = try contacts.map { contact in
                try SearchData.createFromContactItem(contact,
                                                     networkType: currentNetworkType,
                                                     addressFactory: addressFactory)
            }

            return accountsResult + contactsResult
        }

        mapOperation.addDependency(contactsOperation.targetOperation)
        mapOperation.addDependency(accountsOperation)

        let dependencies = contactsOperation.allOperations + [accountsOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: dependencies)
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?> {
        nodeOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        nodeOperationFactory.withdrawOperation(info)
    }
}
