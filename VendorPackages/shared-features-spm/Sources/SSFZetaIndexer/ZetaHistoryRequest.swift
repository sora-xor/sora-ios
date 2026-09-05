import Foundation
import SSFIndexers
import SSFModels
import SSFNetwork

final class ZetaHistoryRequest: RequestConfig {
    init(
        historyUrl: URL,
        chainAsset: ChainAsset,
        address: String
    ) throws {
        var url = historyUrl.appendingPathComponent(address)
        if case .erc20 = chainAsset.asset.ethereumType {
            let contract = chainAsset.asset.id
            url = url.appendingPathComponent("token-transfers")

            var urlComponents = URLComponents(string: url.absoluteString)
            let queryItems = [URLQueryItem(name: "token", value: contract)]
            urlComponents?.queryItems = queryItems

            guard let urlWithParameters = urlComponents?.url else {
                throw HistoryError.urlMissing
            }

            url = urlWithParameters
        } else {
            url = url.appendingPathComponent("transactions")
        }

        super.init(
            baseURL: url,
            method: .get,
            endpoint: nil,
            headers: nil,
            body: nil
        )
    }
}
