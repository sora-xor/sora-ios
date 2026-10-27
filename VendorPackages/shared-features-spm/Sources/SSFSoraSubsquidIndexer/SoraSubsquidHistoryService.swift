import Foundation
import RobinHood
import SSFChainRegistry
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFRuntimeCodingService
import SSFUtils

actor SoraSubsquidHistoryService: HistoryService {
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

        let remoteTransactions = try await remoteHistory.historyElementsConnection.edges
            .map { $0.node }

        let filteredTransactions = remoteTransactions
            .filter { transaction in
                if chainAsset.asset.symbol.lowercased() == "val",
                   transaction.method?.rawValue == "rewarded"
                {
                    return true
                }

                if chainAsset.isUtility,
                   transaction.module?.rawValue == "staking",
                   transaction.method?.rawValue != "rewarded"
                {
                    return true
                }

                if let targetAssetId = transaction.data?.targetAssetId,
                   targetAssetId == chainAsset.asset.tokenProperties?.currencyId
                {
                    return true
                }

                if let baseAssetId = transaction.data?.baseAssetId,
                   baseAssetId == chainAsset.asset.tokenProperties?.currencyId
                {
                    return true
                }

                if let assetId = transaction.data?.assetId,
                   assetId == chainAsset.asset.tokenProperties?.currencyId
                {
                    return true
                }

                return false
            }

        let transactions: [AssetTransactionData] = filteredTransactions.map { item in
            item.createTransactionForAddress(
                address,
                chainAsset: chainAsset
            )
        }

        return try await AssetTransactionPageData(
            transactions: transactions,
            context: remoteHistory.historyElementsConnection.pageInfo?.toPaginationContext()
        )
    }

    private func fetchHistory(
        address: String,
        count: Int,
        cursor: String?,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) async throws -> SoraSubsquidHistoryConnectionResponse {
        let queryString = prepareQueryForAddress(
            address,
            count: count,
            cursor: cursor,
            filters: filters
        )

        let request = try HistoryRequest(
            url: url,
            query: queryString
        )

        let response: GraphQLResponse<SoraSubsquidHistoryConnectionResponse> =
            try await networkWorker.performRequest(with: request)
        return try response.result()
    }

    private func prepareFilter(
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        guard filters.isNotEmpty else {
            return ""
        }

        var filterStrings: [String] = []
        if !filters.contains(where: { $0.type == .swap && $0.selected }) {
            filterStrings.append("\"swap\"")
        }

        if !filters.contains(where: { $0.type == .reward && $0.selected }) {
            filterStrings.append("\"rewarded\"")
        }

        if !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append("\"transfer\"")
        }

        let resultFilters = filterStrings.joined(separator: ",")
        return ", method_not_in: [\(resultFilters)]"
    }

    private func prepareQueryForAddress(
        _ address: String,
        count: Int,
        cursor: String?,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let after: String = cursor.map { "\($0)" } ?? "1"
        let filter = prepareFilter(filters: filters)

        return SoraSubsquidHistoryServiceFilters.query(
            after: after,
            address: address,
            filter: filter,
            count: count
        )
    }
}
