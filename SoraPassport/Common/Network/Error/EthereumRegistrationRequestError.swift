import Foundation

enum EthereumInitDataError: Error {
    case notFound

    static func error(from status: StatusData) -> EthereumInitDataError? {
        switch status.code {
        case "BOUND_ETH_ADDRESS_NOT_FOUND":
            return notFound
        default:
            return nil
        }
    }
}
