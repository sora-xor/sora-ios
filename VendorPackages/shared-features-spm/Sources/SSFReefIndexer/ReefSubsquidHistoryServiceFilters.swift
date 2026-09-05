import Foundation

enum ReefSubsquidHistoryServiceFilters {
    static func transfersConnection(
        after: String,
        address: String,
        count: Int
    ) -> String {
        """
        transfersConnection(\(after),
         first: \(count), where: {AND: [{type_eq: Native}, {OR: [{from: {id_eq: "\(
             address
         )"}}, {to: {id_eq: "\(address)"}}]}]}, orderBy: timestamp_DESC) {
            edges {
                  node {
                    amount
                    timestamp
                    success
            extrinsicHash
                    to {
                      id
                    }
                    from {
                      id
                    }
        signedData
                  }
                }
                pageInfo {
        endCursor
                  hasNextPage
                }
          }
        """
    }

    static func stakingsConnection(
        after: String,
        address: String,
        count: Int
    ) -> String {
        """
                    stakingsConnection(\(after),
             first: \(count), orderBy: timestamp_DESC, where: {AND: {signer: {id_eq: "\(
                 address
             )"}, amount_gt: "0", type_eq: Reward}}) {
                            edges {
                                                              node {
        id
                                                                amount
                                                                timestamp
                                                              }
                                                            }
                                                            pageInfo {
        endCursor
                                                              hasNextPage
                                                            }
                        }
        """
    }

    static func query(with filter: String) -> String {
        """
        query MyQuery {
          \(filter)
        }
        """
    }
}
