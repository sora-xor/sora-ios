import Foundation
import CommonWallet
import RobinHood

struct WalletNetworkSearchErrorFactory: MiddlewareNetworkErrorFactoryProtocol {
    func createErrorFromStatus(_ status: String) -> Error {
        if let searchDataError = WalletSearchDataError.error(from: status) {
            return searchDataError
        } else {
            return NetworkResponseError.unexpectedStatusCode
        }
    }
}
