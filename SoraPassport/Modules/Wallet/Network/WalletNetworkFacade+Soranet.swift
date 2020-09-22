import Foundation
import CommonWallet
import RobinHood

extension WalletNetworkFacade {
    func createSoranetTransferOperation(from info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            guard
                let transferValue = info.context?[WalletOperationContextKey.SoranetTransfer.balance],
                let amount = AmountDecimal(string: transferValue) else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            let fees: [Fee]

            if
                let fee = info.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue }) {
                fees = [fee]
            } else {
                fees = []
            }

            let soranetInfo = TransferInfo(source: info.source,
                                           destination: info.destination,
                                           amount: amount,
                                           asset: info.asset,
                                           details: info.details,
                                           fees: fees)

            return soranetOperationFactory.transferOperation(soranetInfo)
        } catch {
            let operation = BaseOperation<Data>()
            operation.result = .failure(error)
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    func createSoranetWithdrawOperation(from info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            guard
                let withdrawValue = info.context?[WalletOperationContextKey.SoranetWithdraw.balance],
                let amount = AmountDecimal(string: withdrawValue) else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            guard let providerAccountId = info
                .context?[WalletOperationContextKey.SoranetWithdraw.provider] else {
                throw WalletNetworkFacadeError.withdrawProviderMissing
            }

            let fees: [Fee]

            if
                let fee = info.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.withdraw.rawValue }) {
                fees = [fee]
            } else {
                fees = []
            }

            let withdrawInfo = WithdrawInfo(destinationAccountId: providerAccountId,
                                            assetId: info.asset,
                                            amount: amount,
                                            details: info.destination,
                                            fees: fees)

            return soranetOperationFactory.withdrawOperation(withdrawInfo)

        } catch {
            let operation: BaseOperation<Data> = BaseOperation()
            operation.result = .failure(error)
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }
}
