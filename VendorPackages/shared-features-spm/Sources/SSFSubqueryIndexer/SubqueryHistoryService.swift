import Foundation
import RobinHood
import SSFChainRegistry
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFRuntimeCodingService
import SSFUtils

actor SubqueryHistoryService: HistoryService {
    private let txStorage: AsyncAnyRepository<TransactionHistoryItem>
    private let chainRegistry: ChainRegistryProtocol
    private let networkWorker: NetworkWorker

    init(
        txStorage: AsyncAnyRepository<TransactionHistoryItem>,
        chainRegistry: ChainRegistryProtocol,
        networkWorker: NetworkWorker
    ) {
        self.txStorage = txStorage
        self.chainRegistry = chainRegistry
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

        async let remoteHistory = fetchSubqueryHistoryData(
            address: address,
            count: pagination.count,
            cursor: pagination.context?["endCursor"],
            url: baseUrl,
            filters: filters
        )

        let filteredTransactions = try await filter(
            remoteTransactions: remoteHistory.historyElements.nodes,
            chainAsset: chainAsset
        )
        let transactions: [AssetTransactionData] = filteredTransactions.map { item in
            item.createTransactionForAddress(
                address,
                chainAsset: chainAsset
            )
        }

        let result = try await AssetTransactionPageData(
            transactions: transactions,
            context: remoteHistory.historyElements.pageInfo.toContext()
        )
        return result
    }

    // MARK: - Privamte methods

    private func fetchSubqueryHistoryData(
        address: String,
        count: Int,
        cursor: String?,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) async throws -> SubqueryHistoryData {
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

        let response: GraphQLResponse<SubqueryHistoryData> = try await networkWorker
            .performRequest(with: request)
        return try response.result()
    }

    private func prepareFilter(
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        var filterStrings: [String] = []

        if !filters.contains(where: { $0.type == .other && $0.selected }) {
            filterStrings.append("{extrinsic: { isNull: true }}")
        }

        if !filters.contains(where: { $0.type == .reward && $0.selected }) {
            filterStrings.append("{reward: { isNull: true }}")
        }

        if !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append("{transfer: { isNull: true }}")
        }

        return filterStrings.joined(separator: ",")
    }

    private func prepareQueryForAddress(
        _ address: String,
        count: Int,
        cursor: String?,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let after = cursor.map { "\"\($0)\"" } ?? "null"
        let filterString = prepareFilter(filters: filters)
        return """
        {
            historyElements(
                 after: \(after),
                 first: \(count),
                 orderBy: TIMESTAMP_DESC,
                 filter: {
                     address: { equalTo: \"\(address)\"},
                     and: [
                        \(filterString)
                     ]
                 }
             ) {
                 pageInfo {
                     startCursor,
                     endCursor
                 },
                 nodes {
                     id
                     timestamp
                     address
                     reward
                     extrinsic
                     transfer
                 }
             }
        }
        """
    }

    private func filter(
        remoteTransactions: [SubqueryHistoryElement],
        chainAsset: ChainAsset
    ) async throws -> [SubqueryHistoryElement] {
        let coderFactory = try await fetchCoderFactory(
            chainId: chainAsset.chain.chainId
        )

        let filteredTransactions = try remoteTransactions.filter { transaction in
            var assetId: String?

            switch transaction.type {
            case let .transfer(transfer):
                assetId = transfer.assetId
            case let .reward(reward):
                assetId = reward.assetId
            case let .extrinsic(extrinsic):
                assetId = extrinsic.assetId
            case .none:
                assetId = nil
            }

            if chainAsset.chainAssetType != .normal, assetId == nil {
                return false
            }

            if chainAsset.chainAssetType == .normal, assetId != nil {
                return false
            }

            if chainAsset.chainAssetType == .normal, assetId == nil {
                return true
            }

            guard let assetId = assetId else {
                return false
            }

            let assetIdBytes = try Data(hexStringSSF: assetId)
            let encoder = coderFactory.createEncoder()
            guard let currencyId = chainAsset.currencyId else {
                return false
            }

            guard let type = coderFactory.metadata.schema?.types
                .first(where: { $0.type.path.contains("CurrencyId") })?
                .type
                .path
                .joined(separator: "::") else
            {
                return false
            }
            try encoder.append(currencyId, ofType: type)
            let currencyIdBytes = try encoder.encode()

            return currencyIdBytes == assetIdBytes
        }

        return filteredTransactions
    }

    private func fetchCoderFactory(
        chainId: ChainModel.Id
    ) async throws -> RuntimeCoderFactoryProtocol {
        let runtimeService = try await chainRegistry.getRuntimeProvider(
            chainId: chainId,
            usedRuntimePaths: [:],
            runtimeItem: nil
        )
        let coderFactory = try await runtimeService.fetchCoderFactory()
        return coderFactory
    }
}
