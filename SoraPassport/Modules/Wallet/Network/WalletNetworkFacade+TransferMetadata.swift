/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

extension WalletNetworkFacade {
    func createEthereumReceiverMetadata(for info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        let withdrawInfo = WithdrawMetadataInfo(assetId: info.assetId,
                                                option: WalletNetworkConstants.ethWithdrawOptionId)

        let soranetWithdraw = soranetOperationFactory.withdrawalMetadataOperation(withdrawInfo)
        let ethFee = createEthMetadataOperation()
        let xorBalance = createXORBalanceOperationWrapper()
        let bridgeCheck = createBridgeCheckOperation()

        let combiningOperation: BaseOperation<TransferMetaData?> = ClosureOperation {
            let bridgeProof = try bridgeCheck.extractResultData()
            guard let proof = bridgeProof,
                (!proof.allSatisfy { $0 == 0 }) else {
                throw WalletNetworkFacadeError.ethBridgeDisabled
            }

            let xorBalances = try xorBalance.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let withdrawMetadata = try soranetWithdraw.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw WalletNetworkFacadeError.withdrawMetadataMissing
            }

            let mappedSoranetDescriptions: [FeeDescription] = withdrawMetadata.feeDescriptions.map { feeDesc in
                guard feeDesc.assetId == self.valAssetId else {
                    return feeDesc
                }

                var context: [String: String] = feeDesc.context ?? [:]
                context[WalletOperationContextKey.Balance.soranet] = xorBalances.soranet.stringWithPointSeparator
                context[WalletOperationContextKey.Balance.erc20] = xorBalances.ethereum.stringWithPointSeparator
                context[WalletOperationContextKey.Receiver.isMine] =
                    info.receiver.lowercased() == self.ethereumAddress.soraHexWithPrefix.lowercased()
                    ? info.receiver : nil

                return FeeDescription(identifier: feeDesc.identifier,
                                      assetId: feeDesc.assetId,
                                      type: feeDesc.type,
                                      parameters: feeDesc.parameters,
                                      accountId: feeDesc.accountId,
                                      minValue: feeDesc.minValue,
                                      maxValue: feeDesc.maxValue,
                                      context: context)
            }

            let ethFeeDescription = try ethFee.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let context = [
                WalletOperationContextKey.SoranetWithdraw.provider: withdrawMetadata.providerAccountId
            ]

            return TransferMetaData(feeDescriptions: mappedSoranetDescriptions + [ethFeeDescription],
                                    context: context)
        }

        let dependencies = [bridgeCheck] + soranetWithdraw.allOperations + ethFee.allOperations + xorBalance.allOperations

        dependencies.forEach { combiningOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: dependencies)
    }

    func createSoranetReceiverMetadata(for info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        let soranetTransfer = soranetOperationFactory.transferMetadataOperation(info)
        let ethFee = createEthMetadataOperation()
        let xorBalance = createXORBalanceOperationWrapper()

        let combiningOperation: BaseOperation<TransferMetaData?> = ClosureOperation {
            let xorBalances = try xorBalance.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let transferMetadata = try soranetTransfer.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw WalletNetworkFacadeError.transferMetadataMissing
            }

            let mappedSoranetDescriptions: [FeeDescription] = transferMetadata.feeDescriptions.map { feeDesc in
                guard feeDesc.assetId == self.valAssetId else {
                    return feeDesc
                }

                var context: [String: String] = feeDesc.context ?? [:]
                context[WalletOperationContextKey.Balance.soranet] = xorBalances.soranet.stringWithPointSeparator
                context[WalletOperationContextKey.Balance.erc20] = xorBalances.ethereum.stringWithPointSeparator
                context[WalletOperationContextKey.Receiver.isMine] =
                    info.receiver == self.soranetAccountId ? info.receiver : nil

                return FeeDescription(identifier: feeDesc.identifier,
                                      assetId: feeDesc.assetId,
                                      type: feeDesc.type,
                                      parameters: feeDesc.parameters,
                                      accountId: feeDesc.accountId,
                                      minValue: feeDesc.minValue,
                                      maxValue: feeDesc.maxValue,
                                      context: context)
            }

            let ethFeeDescription = try ethFee.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return TransferMetaData(feeDescriptions: mappedSoranetDescriptions + [ethFeeDescription])
        }

        let dependencies = soranetTransfer.allOperations + ethFee.allOperations + xorBalance.allOperations

        dependencies.forEach { combiningOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: dependencies)
    }
}
