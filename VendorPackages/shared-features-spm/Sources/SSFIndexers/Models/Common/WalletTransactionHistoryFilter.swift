import Foundation

public struct WalletTransactionHistoryFilter {
    public enum HistoryFilterType: String {
        case transfer
        case reward
        case swap
        case other

        var id: String {
            switch self {
            case .transfer:
                return "transfer"
            case .reward:
                return "reward"
            case .swap:
                return "swap"
            case .other:
                return "extrinsic"
            }
        }
    }

    public var type: HistoryFilterType
    public var id: String
    public var selected: Bool

    public init(
        type: HistoryFilterType,
        selected: Bool = false
    ) {
        self.type = type
        self.selected = selected
        id = type.id
    }
}
