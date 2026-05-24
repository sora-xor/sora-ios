import Foundation

enum GiantsquidHistoryServiceFilter {
    static func slashesFilter(for address: String) -> String {
        """
            slashes(where: {accountId_containsInsensitive: \"\(address)\"}) {
                accountId
                amount
                blockNumber
                era
                extrinsicHash
                id
                timestamp
        }
            bonds(where: {accountId_containsInsensitive: \"\(address)\"}) {
                accountId
                amount
                blockNumber
                extrinsicHash
                id
                success
                timestamp
                type
        }
        """
    }

    static func rewards(for address: String) -> String {
        """
            rewards(where: {accountId_containsInsensitive: \"\(address)\"}) {
                accountId
                amount
                blockNumber
                era
                extrinsicHash
                id
                timestamp
                validator
            }
        """
    }

    static func transfers(for address: String) -> String {
        """
            transfers(where: {account: {id_eq: "\(address)"}}, orderBy: id_DESC) {
                id
                transfer {
                    amount
                    blockNumber
                    extrinsicHash
                from {
                    id
                }
                to {
                    id
                }
                timestamp
                success
                id
            }
            direction
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
