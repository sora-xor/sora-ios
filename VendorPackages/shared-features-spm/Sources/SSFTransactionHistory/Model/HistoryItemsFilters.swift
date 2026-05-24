import XNetworking

final class GetAllHistoryItemsFilter: HistoryItemsFilter {
    func filterCachedHistoryItems(_ receiver: [TxHistoryItem]) -> [TxHistoryItem] {
        receiver
    }

    func filterPagedHistoryItems(_ receiver: [TxHistoryItem]) -> [TxHistoryItem] {
        receiver
    }
}
