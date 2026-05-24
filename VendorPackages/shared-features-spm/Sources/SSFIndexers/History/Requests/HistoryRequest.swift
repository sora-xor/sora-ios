import Foundation
import RobinHood
import SSFNetwork
import SSFUtils

public final class HistoryRequest: RequestConfig {
    public init(
        url: URL,
        query: String
    ) throws {
        let defaultHeaders = [
            HTTPHeader(
                field: HttpHeaderKey.contentType.rawValue,
                value: HttpContentType.json.rawValue
            ),
        ]

        let info = JSON.dictionaryValue(["query": JSON.stringValue(query)])
        let data = try JSONEncoder().encode(info)

        super.init(
            baseURL: url,
            method: .post,
            endpoint: nil,
            headers: defaultHeaders,
            body: data
        )
    }
}
