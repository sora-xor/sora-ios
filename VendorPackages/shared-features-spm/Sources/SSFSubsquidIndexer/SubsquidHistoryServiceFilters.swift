import Foundation
import SSFIndexers

enum SubsquidHistoryServiceFilters {
    static func query(
        for address: String,
        count: Int,
        cursor: String?,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let filterString = prepareFilter(filters: filters)
        let offset: Int = cursor.map { Int($0) ?? 0 } ?? 0
        return """
        query MyQuery {
          historyElements(where: {address_eq: "\(address)", \(
              filterString
          )}, orderBy: timestamp_DESC, limit: \(count), offset: \(offset)) {
            timestamp
            id
            extrinsicIdx
            extrinsicHash
            blockNumber
            address
                                    extrinsic {
                                      call
                                      fee
                                      hash
                                      module
                                      success
                                    }
                    transfer {
                    amount
                    eventIdx
                    fee
                    from
                    success
                    to
                    }
                                reward {
                                  amount
                                  era
                                  eventIdx
                                  isReward
                                  stash
                                  validator
                                }
          }
        }
        """
    }

    static func prepareFilter(
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        var filterStrings: [String] = []

        if !filters.contains(where: { $0.type == .other && $0.selected }) {
            filterStrings.append("extrinsic_isNull: true")
        }

        if !filters.contains(where: { $0.type == .reward && $0.selected }) {
            filterStrings.append("reward_isNull: true")
        }

        if !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append("transfer_isNull: true")
        }

        return filterStrings.joined(separator: ",")
    }
}
