import Foundation
import RobinHood
import SSFIndexers
import SSFModels
import SSFNetwork
import SSFUtils

enum EtherscanHistoryServiceError: Error {
    case remoteResultNotFetched
}

final actor EtherscanHistoryService: HistoryService {
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
    ) async throws -> EtherscanHistoryResponse {
        guard let baseURL = chainAsset.chain.externalApi?.history?.url else {
            throw HistoryError.urlMissing
        }

        let request = EtherscanHistoryRequest(
            baseURL: baseURL,
            chainAsset: chainAsset,
            address: address
        )

        let response: EtherscanHistoryResponse = try await networkWorker
            .performRequest(with: request)
        return response
    }

    private func createMap(
        remote: EtherscanHistoryResponse,
        address: String,
        chainAsset: ChainAsset
    ) throws -> AssetTransactionPageData {
        guard let result = remote.result else {
            throw EtherscanHistoryServiceError.remoteResultNotFetched
        }
        let asset = chainAsset.asset
        let transactions = result
            .filter { element in
                guard asset.ethereumType != .normal else {
                    return true
                }
                return element.contractAddress?.lowercased() == asset.id.lowercased()
            }
            .sorted(by: { $0.timestampInSeconds > $1.timestampInSeconds })
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
