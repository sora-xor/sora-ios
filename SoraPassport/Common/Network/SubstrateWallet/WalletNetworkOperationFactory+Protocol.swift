import BigInt
import CommonWallet
import FearlessUtils
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

        guard let receiver = try? Data(hexString: info.receiver) else {
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
            let paymentInfo = try feeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let fee = BigUInt(paymentInfo.fee),
                  let decimalFee = Decimal.fromSubstrateAmount(fee, precision: feeAsset.precision) else {
                return nil
            }

            let amount = AmountDecimal(value: decimalFee)

            let feeDescription = FeeDescription(identifier: feeAsset.identifier, assetId: feeAsset.identifier,
                                                type: FeeType.fixed.rawValue, parameters: [amount])

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
        switch info.type {
        case .swap:
            return swapOperationWrapper(info)
        // TBD       case .addLiquidity, .removeLiquidity...
        default:
            return transferOperationWrapper(info)
        }
    }
    
    private func transferOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard
            let asset = accountSettings.assets.first(where: { $0.identifier == info.asset }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return createCompoundOperation(result: .failure(error))
        }

        guard let amount = info.amount.decimalValue.toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return createCompoundOperation(result: .failure(error))
        }

        let chain = asset.chain

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let transferCall = try callFactory.transfer(to: info.destination, asset: asset.identifier, amount: amount)

            return try builder
                .adding(call: transferCall)
        }

        let transferOperation = createExtrinsicServiceOperation(closure: closure)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexString: hashString)
        }

        mapOperation.addDependency(transferOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: [transferOperation])
    }

    private func swapOperationWrapper(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard
            let asset = accountSettings.assets.first(where: { $0.identifier == info.asset }),
            let destinationAsset = accountSettings.assets.first(where: { $0.identifier == info.destination }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return createCompoundOperation(result: .failure(error))
        }

        guard let context = info.context else {
            let error = WalletNetworkOperationFactoryError.invalidContext
            return createCompoundOperation(result: .failure(error))
        }

        guard let amountCall = info.amountCall else {
            let error = WalletNetworkOperationFactoryError.invalidReceiver
            return createCompoundOperation(result: .failure(error))
        }

        let sourceType: String = context[TransactionContextKeys.marketType] ?? ""
        let marketType: LiquiditySourceType = LiquiditySourceType(rawValue: sourceType) ?? .smart
        let marketCode = marketType.code
        let filter = marketType.filter

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let call = try SubstrateCallFactory().swap(from: asset.identifier, to: info.destination, amountCall: amountCall, type: marketCode, filter: filter)
            return try builder.adding(call: call)
        }

        let wrapper = createExtrinsicServiceOperation(closure: builderClosure)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try wrapper
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexString: hashString)
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
}
