import Foundation
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFUtils

final actor GiantsquidHistoryService: HistoryService {
    private enum GiantsquidConfig {
        static let giantsquidRewardsEnabled = false
        static let giantsquidExtrinsicEnabled = false
    }

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

        guard !historyContext.isComplete, chainAsset.isUtility,
              let baseUrl = chainAsset.chain.externalApi?.history?.url else
        {
            return nil
        }

        async let remoteHistory = fetchHistory(
            address: address,
            url: baseUrl,
            filters: filters
        )

        let transactions: [AssetTransactionData] = try await remoteHistory.history.map { item in
            item.createTransactionForAddress(
                address,
                chainAsset: chainAsset
            )
        }

        return AssetTransactionPageData(
            transactions: transactions,
            context: nil
        )
    }

    // MARK: - Private methods

    private func fetchHistory(
        address: String,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) async throws -> GiantsquidResponseData {
        let queryString = prepareQueryForAddress(
            address,
            filters: filters
        )

        let request = try HistoryRequest(
            url: url,
            query: queryString
        )

        let response: GraphQLResponse<GiantsquidResponseData> = try await networkWorker
            .performRequest(with: request)
        return try response.result()
    }

    private func prepareFilter(
        filters: [WalletTransactionHistoryFilter],
        address: String
    ) -> String {
        var filterStrings: [String] = []

        if filters.contains(where: { $0.type == .other && $0.selected }),
           GiantsquidConfig.giantsquidExtrinsicEnabled
        {
            filterStrings.append(
                GiantsquidHistoryServiceFilter.slashesFilter(for: address)
            )
        }

        if filters.contains(where: { $0.type == .reward && $0.selected }),
           GiantsquidConfig.giantsquidRewardsEnabled
        {
            filterStrings.append(
                GiantsquidHistoryServiceFilter.rewards(for: address)
            )
        }

        if filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append(
                GiantsquidHistoryServiceFilter.transfers(for: address)
            )
        }

        return filterStrings.joined(separator: "\n")
    }

    private func prepareQueryForAddress(
        _ address: String,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let filterString = prepareFilter(filters: filters, address: address)
        return GiantsquidHistoryServiceFilter.query(with: filterString)
    }
}
