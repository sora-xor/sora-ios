import Foundation

enum WalletSearchDataError: Error {
    case invalidQuery

    static func error(from statusString: String) -> WalletSearchDataError? {
        switch statusString {
        case "INCORRECT_QUERY_PARAMS":
            return .invalidQuery
        default:
            return nil
        }
    }
}
