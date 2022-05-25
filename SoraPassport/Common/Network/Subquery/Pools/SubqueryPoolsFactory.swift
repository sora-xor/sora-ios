import FearlessUtils
import Foundation
import RobinHood

protocol SubqueryPoolsFactoryProtocol {
    func getStrategicBonusAPYOperation() -> BaseOperation<SubqueryPoolInfoPool>
}

final class SubqueryPoolsFactory {
    let url: URL
    let filter: [String]

    init(url: URL, filter: [String] = []) {
        self.url = url
        self.filter = filter
    }

    private func prepareQuery() -> String {
        """
        query {
            poolXYKEntities (first: 1 orderBy: UPDATED_DESC)
              {
                nodes {
                  pools {
                    edges {
                      node {
                        targetAssetId,
                        priceUSD,
                        strategicBonusApy
                      }
                    }
                  }
                }
              }
            }
        """
    }
}

extension SubqueryPoolsFactory: SubqueryPoolsFactoryProtocol {
    func getStrategicBonusAPYOperation() -> BaseOperation<SubqueryPoolInfoPool> {
        let queryString = prepareQuery()

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

        let resultFactory = AnyNetworkResultFactory<SubqueryPoolInfoPool> { data in
            do {
                let response = try JSONDecoder().decode(SubqueryResponse<SubqueryPoolsInfoData>.self, from: data)
                switch response {
                case let .errors(error):
                    print(error)
                    throw error
                case let .data(response):
                    return response.poolXYKEntities.nodes.first!.pools
                }
            } catch {
                print(error)
                throw error
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
