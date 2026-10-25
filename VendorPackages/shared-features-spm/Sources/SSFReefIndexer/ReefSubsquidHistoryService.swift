import Foundation
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFUtils

actor ReefSubsquidHistoryService: HistoryService {
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
              chainAsset.isUtility,
              let baseUrl = chainAsset.chain.externalApi?.history?.url else
        {
            return nil
        }

        async let subqueryHistory = try await fetchHistory(
            address: address,
            url: baseUrl,
            filters: filters,
            count: 20,
            transfersCursor: pagination.context?["transfersCursor"],
            stakingsCursor: pagination.context?["stakingsCursor"]
        )

        let subqueryTransactions: [AssetTransactionData] = try await subqueryHistory.history
            .sorted(by: { item1, item2 in
                item1.itemTimestamp > item2.itemTimestamp
            }).map { item in
                item.createTransactionForAddress(
                    address,
                    chainAsset: chainAsset
                )
            }

        let map = try await createHistoryMap(
            subqueryItems: subqueryTransactions,
            reefData: subqueryHistory
        )
        return map
    }

    // MARK: - Private methods

    private func fetchHistory(
        address: String,
        url: URL,
        filters: [WalletTransactionHistoryFilter],
        count: Int,
        transfersCursor: String?,
        stakingsCursor: String?
    ) async throws -> ReefResponseData {
        let queryString = prepareQueryForAddress(
            address,
            filters: filters,
            count: count,
            transfersCursor: transfersCursor,
            stakingsCursor: stakingsCursor
        )

        let request = try HistoryRequest(
            url: url,
            query: queryString
        )

        let response: GraphQLResponse<ReefResponseData> = try await networkWorker
            .performRequest(with: request)
        return try response.result()
    }

    private func prepareFilter(
        filters: [WalletTransactionHistoryFilter],
        address: String,
        count: Int,
        transfersCursor: String?,
        stakingsCursor: String?
    ) -> String {
        var filterStrings: [String] = []

        if filters.contains(where: { $0.type == .transfer && $0.selected }) {
            let transfersAfter = transfersCursor.map { "after: \"\($0)\"" } ?? ""
            filterStrings.append(
                ReefSubsquidHistoryServiceFilters.transfersConnection(
                    after: transfersAfter,
                    address: address,
                    count: count
                )
            )
        }

        if filters.contains(where: { $0.type == .reward && $0.selected }) {
            let stakingsAfter = stakingsCursor.map { "after: \"\($0)\"" } ?? ""
            filterStrings.append(
                ReefSubsquidHistoryServiceFilters.stakingsConnection(
                    after: stakingsAfter,
                    address: address,
                    count: count
                )
            )
        }

        return filterStrings.joined(separator: "\n")
    }

    private func prepareQueryForAddress(
        _ address: String,
        filters: [WalletTransactionHistoryFilter],
        count: Int,
        transfersCursor: String?,
        stakingsCursor: String?
    ) -> String {
        let filterString = prepareFilter(
            filters: filters,
            address: address,
            count: count,
            transfersCursor: transfersCursor,
            stakingsCursor: stakingsCursor
        )
        return ReefSubsquidHistoryServiceFilters.query(with: filterString)
    }

    private func createHistoryMap(
        subqueryItems: [AssetTransactionData],
        reefData: ReefResponseData
    ) -> AssetTransactionPageData {
        let isTransfersHasNextPage = (reefData.transfersConnection?.pageInfo?.hasNextPage).or(false)
        let isStakingHasNextPage = (reefData.stakingsConnection?.pageInfo?.hasNextPage).or(false)
        let hasNextPage = isTransfersHasNextPage || isStakingHasNextPage

        guard hasNextPage else {
            return AssetTransactionPageData(
                transactions: subqueryItems,
                context: nil
            )
        }

        var context: [String: String] = [:]
        if let transfersCursor = reefData.transfersConnection?.pageInfo?.endCursor {
            context["transfersCursor"] = transfersCursor
        }

        if let stakingsCursor = reefData.stakingsConnection?.pageInfo?.endCursor {
            context["stakingsCursor"] = stakingsCursor
        }

        return AssetTransactionPageData(
            transactions: subqueryItems,
            context: context
        )
    }
}
