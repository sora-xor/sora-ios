import BigInt
import Foundation
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFUtils

final actor ZetaHistoryService: HistoryService {
    private let networkWorker: NetworkWorker

    init(networkWorker: NetworkWorker) {
        self.networkWorker = networkWorker
    }

    // MARK: - HistoryService

    func fetchTransactionHistory(
        chainAsset: ChainAsset,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination _: Pagination
    ) async throws -> AssetTransactionPageData? {
        let remote = try await fetchHistory(
            address: address,
            chainAsset: chainAsset
        )

        let map = createMap(
            remote: remote,
            address: address,
            chainAsset: chainAsset
        )
        return map
    }

    // MARK: - Private methods

    private func fetchHistory(
        address: String,
        chainAsset: ChainAsset
    ) async throws -> ZetaHistoryResponse {
        guard let historyUrl = chainAsset.chain.externalApi?.history?.url else {
            throw HistoryError.urlMissing
        }

        let request = try ZetaHistoryRequest(
            historyUrl: historyUrl,
            chainAsset: chainAsset,
            address: address
        )

        let response: ZetaHistoryResponse = try await networkWorker.performRequest(with: request)
        return response
    }

    private func createMap(
        remote: ZetaHistoryResponse,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionPageData? {
        let transactions = remote.items
            .compactMap {
                AssetTransactionData.createTransaction(
                    from: $0,
                    address: address,
                    chainAsset: chainAsset
                )
            }
            .filter { ($0.amount?.decimalValue ?? 0) > 0 }
            .sorted(by: { $0.timestamp ?? 0 > $1.timestamp ?? 0 })

        return AssetTransactionPageData(transactions: transactions)
    }
}
