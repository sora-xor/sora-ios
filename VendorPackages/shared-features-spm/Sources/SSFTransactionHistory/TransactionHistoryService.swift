import Foundation
import SSFModels
import SSFUtils
import XNetworking

public enum TransactionHistoryServiceError: Error {
    case unexpectedError
}

public protocol TransactionHistoryService {
    func getTransactionPage(
        selectedAccountAddress: String,
        pageIndex: Int,
        chainId: String
    ) async throws -> HistoryPage
}

public actor TransactionHistoryServiceDefault: TransactionHistoryService {
    private let repository: TxHistoryRepository

    public init() {
        let factory = ExpectActualDBDriverFactory(name: "com.soramitsu.db.transaction.history")
        let config = RestClientConfig()
        let chainsRequestUrl = ApplicationSourcesImpl.shared.chainsSourceUrl.absoluteString
        let restClient = RestClientImpl(restClientConfig: config)
        let configParser = RemoteConfigParserImpl(
            restClient: restClient,
            chainsRequestUrl: chainsRequestUrl
        )
        let configDAO = SuperWalletConfigDAOImpl(configParser: configParser)
        let filter = GetAllHistoryItemsFilter()

        repository = TxHistoryRepositoryImpl(
            databaseDriverFactory: factory,
            configDAO: configDAO,
            restClient: restClient,
            historyItemsFilter: filter
        )
    }

    public func getTransactionPage(
        selectedAccountAddress: String,
        pageIndex: Int,
        chainId: String
    ) async throws -> HistoryPage {
        try await withCheckedThrowingContinuation { continuation in
            repository.getTransactionHistoryPaged(
                address: selectedAccountAddress,
                page: Int64(pageIndex + 1),
                pageCount: 50,
                chainInfo: ChainInfo.Simple(chainId: chainId),
                filters: [TxFilter.extrinsic, TxFilter.reward, TxFilter.transfer]
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: TransactionHistoryServiceError.unexpectedError)
                    return
                }

                guard let items = result.items as? [TxHistoryItem] else {
                    continuation.resume(throwing: TransactionHistoryServiceError.unexpectedError)
                    return
                }

                let transactions = self.map(
                    items: items,
                    selectedAccountAddress: selectedAccountAddress
                )

                continuation.resume(returning: HistoryPage(
                    transactions: transactions,
                    endReached: result.endReached
                ))
            }
        }
    }

    private func map(items: [TxHistoryItem], selectedAccountAddress: String) -> [Transaction] {
        items.compactMap { item in
            guard let callPath = TransactionHistorySupportedCodingPath(path: (
                item.module,
                item.method
            )) else {
                return nil
            }

            let status: TransactionStatus = item.success ? .success : .failed
            let fee = SubstrateAmountDecimal(string: item.networkFee)?.decimalValue
            let context = TransactionContext(
                callPath: callPath,
                userAccountAddress: selectedAccountAddress,
                item: item
            )

            return Transaction(
                txHash: item.id,
                blockHash: item.blockHash,
                fee: fee,
                status: status,
                timestamp: item.timestamp,
                context: context
            )
        }
    }
}
