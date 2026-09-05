import Foundation

enum SoraSubsquidHistoryServiceFilters {
    static func query(
        after: String,
        address: String,
        filter: String,
        count: Int
    ) -> String {
        """
        query MyQuery {
                  historyElementsConnection(
                    where: {
                      OR: [
                        { address_eq: "\(address)"\(filter) },
                        { dataTo_eq: "\(address)"\(filter) },
                      ]
                    },
                    after: "\(after)"
                    first: \(count),
                    orderBy: timestamp_DESC,
                  ) {
                    pageInfo {
                      endCursor
                      hasNextPage
                      hasPreviousPage
                      startCursor
                    }
                    totalCount
                    edges {
                      node {
                        address
                        blockHash
                        blockHeight
                        callNames
                        data
                        dataFrom
                        dataTo
                        id
                        method
                        module
                        name
                        networkFee
                        timestamp
                        type
                        updatedAtBlock
                        execution {
                          success
                        }
                      }
                    }
                  }
                }
        """
    }
}
