import FearlessUtils
import Foundation
import RobinHood

protocol SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        address: String,
        count: Int,
        after: String
    ) -> BaseOperation<SubqueryHistoryData>
}

final class SubqueryHistoryOperationFactory {
    let url: URL
    let filter: WalletHistoryFilter

    init(url: URL, filter: WalletHistoryFilter) {
        self.url = url
        self.filter = filter
    }

    /// Subquery: https://soramitsu.atlassian.net/wiki/spaces/SP/pages/3448406051/Sora+Subquery
    private func prepareQueryForAddress(_ address: String, count: Int, after: String) -> String {
        return """
        query {
          historyElements(
            first: \(count)
            orderBy: TIMESTAMP_DESC
            after: "\(after)"
            filter: {
              or: [
                {
                  address: {
                    equalTo: "\(address)"
                  }
                  or: [
                    { module: { equalTo: "assets" }, method: { equalTo: "transfer" } }
                    {
                      module: { equalTo: "liquidityProxy" }
                      method: { equalTo: "swap" }
                    }
                    {
                      module: { equalTo: "poolXYK" }
                      method: { equalTo: "depositLiquidity" }
                    }
                    {
                      module: { equalTo: "poolXYK" }
                      method: { equalTo: "withdrawLiquidity" }
                    }
                    { data: { contains: [{ method: "depositLiquidity" }] } }
                    { data: { contains: [{ method: "withdrawLiquidity" }] } }
                  ]
                }
                {
                  data: {
                    contains: {
                      to: "\(address)"
                    }
                  }
                  execution: { contains: { success: true } }
                }
              ]
            }
          ) {
            nodes {
              id
              blockHash
              module
              method
              address
              networkFee
              execution
              timestamp
              data
            }
            pageInfo {
              endCursor
              hasNextPage
            }
          }
        }
        """
    }
}

extension SubqueryHistoryOperationFactory: SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        address: String,
        count: Int,
        after: String
    ) -> BaseOperation<SubqueryHistoryData> {
        let queryString = prepareQueryForAddress(address, count: count, after: after)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryHistoryData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryHistoryData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
