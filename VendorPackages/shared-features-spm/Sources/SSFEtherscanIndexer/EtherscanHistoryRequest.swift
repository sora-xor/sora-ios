import Foundation
import SSFModels
import SSFNetwork

final class EtherscanHistoryRequest: RequestConfig {
    init(
        baseURL: URL,
        chainAsset: ChainAsset,
        address: String
    ) {
        let action: String = chainAsset.asset.ethereumType == .normal ? "txlist" : "tokentx"
        var queryItems = [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "address", value: address),
        ]

        if let apiKey = chainAsset.chain.externalApi?.history?.apiKey {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
        }

        super.init(
            baseURL: baseURL,
            method: .get,
            endpoint: nil,
            queryItems: queryItems,
            headers: nil,
            body: nil
        )
    }
}
