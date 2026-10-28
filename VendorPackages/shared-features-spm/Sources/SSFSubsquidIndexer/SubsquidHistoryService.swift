import Foundation
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFUtils

final actor SubsquidHistoryService: HistoryService {
    private let txStorage: AsyncAnyRepository<TransactionHistoryItem>
    private let networkWorker: NetworkWorker

    init(
        txStorage: AsyncAnyRepository<TransactionHistoryItem>,
        networkWorker: NetworkWorker
    ) {
        self.txStorage = txStorage
        self.networkWorker = networkWorker
    }

    // MARK: - HistoryService

    func fetchTransactionHistory(
        chainAsset: ChainAsset,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) async throws -> AssetTransactionPageData? {
        let historyContext = TransactionHistoryContext(
            context: pagination.context ?? [:],
            defaultRow: pagination.count
        ).byApplying(filters: filters)

        guard !historyContext.isComplete,
              let baseUrl = chainAsset.chain.externalApi?.history?.url else
        {
            return nil
        }

        async let remoteHistory = fetchHistory(
            address: address,
            count: pagination.count,
            cursor: pagination.context?["endCursor"],
            url: baseUrl,
            filters: filters
        )

        let filteredTransactions = try await remoteHistory.historyElements
            .sorted { element1, element2 in
                element2.timestampInSeconds < element1.timestampInSeconds
            }

        let transactions: [AssetTransactionData] = filteredTransactions.map { item in
            item.createTransactionForAddress(
                address,
                chainAsset: chainAsset
            )
        }

        let map = createSubqueryHistoryMap(
            transactions: transactions,
            pagination: pagination
        )
        return map
    }

    // MARK: - Private methods

    private func fetchHistory(
        address: String,
        count: Int,
        cursor: String?,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) async throws -> SubsquidHistoryResponse {
        let queryString = SubsquidHistoryServiceFilters.query(
            for: address,
            count: count,
            cursor: cursor,
            filters: filters
        )

        let request = try HistoryRequest(
            url: url,
            query: queryString
        )

        let response: GraphQLResponse<SubsquidHistoryResponse> = try await networkWorker
            .performRequest(with: request)
        return try response.result()
    }

    private func createSubqueryHistoryMap(
        transactions: [AssetTransactionData],
        pagination: Pagination
    ) -> AssetTransactionPageData? {
        let context = pagination.context
        let endCursor = context
            .map { (Int($0["endCursor"] ?? "0") ?? 0) + pagination.count } ?? pagination.count
        return AssetTransactionPageData(
            transactions: transactions,
            context: ["endCursor": "\(endCursor)"]
        )
    }
}
