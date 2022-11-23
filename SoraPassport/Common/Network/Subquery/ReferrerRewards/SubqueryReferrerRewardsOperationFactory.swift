import FearlessUtils
import Foundation
import RobinHood

protocol SubqueryReferrerRewardsOperationFactoryProtocol {
    func createOperation(referrer: String) -> BaseOperation<SubqueryReferrerRewardsData>
}

final class SubqueryReferrerRewardsOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    private func prepareQueryFor(_ referrer: String) -> String {
        return """
        query {
        referrerRewards (
            filter: {
                referrer: { equalTo: "\(referrer)" }
            }) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              id
              blockHeight
              referral
              referrer
              timestamp
              amount
            }
          }
        }
        """
    }
}

extension SubqueryReferrerRewardsOperationFactory: SubqueryReferrerRewardsOperationFactoryProtocol {
    func createOperation(referrer: String) -> BaseOperation<SubqueryReferrerRewardsData> {
        let queryString = prepareQueryFor(referrer)

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

        let resultFactory = AnyNetworkResultFactory<SubqueryReferrerRewardsData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryReferrerRewardsData>.self,
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
