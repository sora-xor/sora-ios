import SSFModels

public enum HistoryError: Error {
    case urlMissing
    case missingHistoryType(chainId: ChainModel.Id)
}

public protocol HistoryService: Actor {
    func fetchTransactionHistory(
        chainAsset: ChainAsset,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) async throws -> AssetTransactionPageData?
}
