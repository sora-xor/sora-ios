import Foundation
import RobinHood

extension WalletNetworkFacade {
    func createXORBalanceOperationWrapper() -> CompoundOperationWrapper<TokenBalancesData> {
        let soranetWrapper = soranetOperationFactory.fetchBalanceOperation([xorAssetId])

        let contractAddressOperation = ethereumOperationFactory
            .createXORAddressFetchOperation(from: masterContractAddress)

        let ethAddressConfig: EthAddressConfig = {
            try contractAddressOperation
                    .extractResultData(throwing: BaseOperationError.unexpectedDependentResult)
        }

        let erc20balanceOperation = ethereumOperationFactory
            .createERC20TokenBalanceFetchOperation(from: ethAddressConfig)

        erc20balanceOperation.addDependency(contractAddressOperation)

        let combiningOperation: BaseOperation<TokenBalancesData> = ClosureOperation {
            guard let soranetBalance = try soranetWrapper.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?.first else {
                throw WalletNetworkFacadeError.emptyBalance
            }

            let soranetDecimalValue = soranetBalance.balance.decimalValue

            let ercValue = try erc20balanceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let ercDecimalValue = Decimal.fromEthereumAmount(ercValue) else {
                throw WalletNetworkFacadeError.brokenAmountValue
            }

            return TokenBalancesData(soranet: soranetDecimalValue, ethereum: ercDecimalValue)
        }

        combiningOperation.addDependency(erc20balanceOperation)
        combiningOperation.addDependency(soranetWrapper.targetOperation)

        let dependencies = soranetWrapper.allOperations + [contractAddressOperation, erc20balanceOperation]

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: dependencies)
    }
}
