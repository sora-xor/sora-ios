import Foundation
import SSFModels
import SSFNetwork

final class OklinkHistoryRequest: RequestConfig {
    init(
        baseUrl: URL,
        chainAsset: ChainAsset,
        address: String
    ) {
        let queryItems = [
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "symbol", value: chainAsset.asset.symbol.lowercased()),
        ]

        var headers: [HTTPHeader]?
        if let apiKey = chainAsset.chain.externalApi?.history?.apiKey {
            headers?.append(HTTPHeader(field: "Ok-Access-Key", value: apiKey))
        }

        super.init(
            baseURL: baseUrl,
            method: .get,
            endpoint: nil,
            queryItems: queryItems,
            headers: headers,
            body: nil
        )
    }
}
