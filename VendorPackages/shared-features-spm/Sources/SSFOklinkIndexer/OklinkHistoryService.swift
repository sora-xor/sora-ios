import Foundation
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFUtils

enum OklinkHistoryServiceError: Error {
    case remoteResultNotFetched
}

final actor OklinkHistoryService: HistoryService {
    private let networkWorker: NetworkWorker

    init(networkWorker: NetworkWorker) {
        self.networkWorker = networkWorker
    }

    // MARK: - HistoryService

    func fetchTransactionHistory(
        chainAsset: SSFModels.ChainAsset,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination _: Pagination
    ) async throws -> AssetTransactionPageData? {
        let remote = try await fetchHistory(
            address: address,
            chainAsset: chainAsset
        )

        let map = try createMap(
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
    ) async throws -> OklinkHistoryResponse {
        guard let historyUrl = chainAsset.chain.externalApi?.history?.url else {
            throw HistoryError.urlMissing
        }

        let request = OklinkHistoryRequest(
            baseUrl: historyUrl,
            chainAsset: chainAsset,
            address: address
        )

        let response: OklinkHistoryResponse = try await networkWorker.performRequest(with: request)
        return response
    }

    private func createMap(
        remote: OklinkHistoryResponse,
        address: String,
        chainAsset: ChainAsset
    ) throws -> AssetTransactionPageData {
        guard let remoteTransactions = remote.data.first?.transactionLists else {
            throw OklinkHistoryServiceError.remoteResultNotFetched
        }
        let asset = chainAsset.asset
        let isNormalAsset = asset.ethereumType == .normal

        let transactions = remoteTransactions
            .filter {
                if isNormalAsset {
                    return true
                } else {
                    return $0.tokenContractAddress.lowercased() == asset.id.lowercased()
                }
            }
            .sorted(by: { $0.transactionTime > $1.transactionTime })
            .map {
                AssetTransactionData.createTransaction(
                    from: $0,
                    address: address,
                    chainAsset: chainAsset
                )
            }
            .filter { ($0.amount?.decimalValue ?? 0) > 0 }

        return AssetTransactionPageData(transactions: transactions)
    }
}
