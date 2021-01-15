/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import BigInt

extension WalletNetworkFacade {
    func createBridgeCheckOperation() -> BaseOperation<Data> {
        let bridgeCheckOperation = ethereumOperationFactory.createBridgeCheckOperation(for: { Data() },
                                                                                       masterContractAddress: masterContractAddress)
        return bridgeCheckOperation
    }

    func createEthMetadataOperation() -> CompoundOperationWrapper<FeeDescription> {
        let gasPriceOperation = ethereumOperationFactory.createGasPriceOperation()
        let ethBalanceOperation = ethereumOperationFactory.createEthBalanceFetchOperation()

        let assetId = ethAssetId

        let combiningOperation: BaseOperation<FeeDescription> = ClosureOperation {

            let priceValue = try gasPriceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let priceDecimal = Decimal.fromEthereumAmount(priceValue) else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            let ethValue = try ethBalanceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let ethDecimal = Decimal.fromEthereumAmount(ethValue) else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            let transferGas = AmountDecimal(value: Decimal(EthereumGasLimit.estimated.transfer))
            let mintGas = AmountDecimal(value: Decimal(EthereumGasLimit.estimated.mint))

            let parameters = EthFeeParameters(transferGas: transferGas,
                                              mintGas: mintGas,
                                              gasPrice: AmountDecimal(value: priceDecimal),
                                              balance: AmountDecimal(value: ethDecimal))

            return FeeDescription(identifier: WalletNetworkConstants.ethFeeIdentifier,
                                  assetId: assetId,
                                  type: WalletFeeType.fixed.rawValue,
                                  parameters: parameters)
        }

        combiningOperation.addDependency(gasPriceOperation)
        combiningOperation.addDependency(ethBalanceOperation)

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: [gasPriceOperation, ethBalanceOperation])
    }

    func createERC20TransferOperation(from info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            guard
                let transferValue = info.context?[WalletOperationContextKey.ERC20Transfer.balance],
                let amountDecimal = AmountDecimal(string: transferValue),
                let erc20Value = amountDecimal.decimalValue.toEthereumAmount() else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            guard
                let fee = info.fees
                    .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }),
                let gasLimit = BigUInt(fee.feeDescription.parameters.transferGas.stringValue),
                let gasPrice = fee.feeDescription.parameters.gasPrice
                    .decimalValue.toEthereumAmount() else {
                throw WalletNetworkFacadeError.ethFeeMissingOrBroken
            }

            let destinationAddress = Data(hex: info.destination)

            return prepareERC20TransferWrapperToAddress(destinationAddress,
                                                        amount: erc20Value,
                                                        gasLimit: gasLimit,
                                                        gasPrice: gasPrice)

        } catch {
            let operation: BaseOperation<Data> = BaseOperation()
            operation.result = .failure(error)
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func createERC20WithdrawOperation(from info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            guard
                let withdrawValue = info.context?[WalletOperationContextKey.ERC20Withdraw.balance],
                let amountDecimal = AmountDecimal(string: withdrawValue),
                let erc20Value = amountDecimal.decimalValue.toEthereumAmount() else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            guard
                let fee = info.fees
                    .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }),
                let gasLimit = BigUInt(fee.feeDescription.parameters.mintGas.stringValue),
                let gasPrice = fee.feeDescription.parameters.gasPrice
                    .decimalValue.toEthereumAmount() else {
                throw WalletNetworkFacadeError.ethFeeMissingOrBroken
            }

            return prepareERC20TransferWrapperToAddress(masterContractAddress,
                                                        amount: erc20Value,
                                                        gasLimit: gasLimit,
                                                        gasPrice: gasPrice)

        } catch {
            let operation: BaseOperation<Data> = BaseOperation()
            operation.result = .failure(error)
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func prepareERC20TransferWrapperToAddress(_ address: Data,
                                              amount: BigUInt,
                                              gasLimit: BigUInt,
                                              gasPrice: BigUInt) -> CompoundOperationWrapper<Data> {
        let xorAddressOperation = ethereumOperationFactory
            .createXORAddressFetchOperation(from: masterContractAddress)

        let transferConfig: EthERC20TransferConfig = {
            let tokenAddress = try xorAddressOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return ERC20TransferInfo(tokenAddress: tokenAddress,
                                     destinationAddress: address,
                                     amount: amount)
        }

        let transferOperation = ethereumOperationFactory
            .createERC20TransferTransactionOperation(for: transferConfig)

        transferOperation.addDependency(xorAddressOperation)

        let nonceOperation = ethereumOperationFactory.createTransactionsCountOperation(with: .pending)

        let transactionConfig: EthReadyTransactionConfig = {
            let txData = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let nonce = try nonceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return EthereumTransactionInfo(txData: txData,
                                           gasPrice: gasPrice,
                                           gasLimit: gasLimit,
                                           nonce: nonce)
        }

        let transactionOperation = ethereumOperationFactory
            .createSendTransactionOperation(for: transactionConfig)
        transactionOperation.addDependency(nonceOperation)
        transactionOperation.addDependency(transferOperation)

        let dependencies = [xorAddressOperation, nonceOperation, transferOperation]

        return CompoundOperationWrapper(targetOperation: transactionOperation,
                                        dependencies: dependencies)
    }
}
