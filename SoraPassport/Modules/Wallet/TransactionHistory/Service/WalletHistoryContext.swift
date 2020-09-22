/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

typealias WalletHistoryContext = [String: String]

private struct WalletHistoryContextKeys {
    static let remoteOffset = "co.jp.sora.history.remote.offset"
    static let transferOffset = "co.jp.sora.history.transfer.offset"
    static let withdrawOffset = "co.jp.sora.history.withdraw.offset"
    static let depositOffset = "co.jp.sora.history.deposit.offset"
    static let ignoringIds = "co.jp.sora.history.ignore.ids"
}

extension WalletHistoryContext {
    static var initial: WalletHistoryContext {
        WalletHistoryContext(ignoringIds: [],
                             remoteOffset: 0,
                             transferOffset: 0,
                             withdrawOffset: 0,
                             depositOffset: 0)
    }

    var remoteOffset: Int? {
        offsetForKey(WalletHistoryContextKeys.remoteOffset)
    }

    var transferOffset: Int? {
        offsetForKey(WalletHistoryContextKeys.transferOffset)
    }

    var withdrawOffset: Int? {
        offsetForKey(WalletHistoryContextKeys.withdrawOffset)
    }

    var depositOffset: Int? {
        offsetForKey(WalletHistoryContextKeys.depositOffset)
    }

    var ignoringIds: Set<String> {
        if let list = self[WalletHistoryContextKeys.ignoringIds]?.components(separatedBy: ",") {
            return Set(list)
        } else {
            return []
        }
    }

    init(ignoringIds: Set<String>,
         remoteOffset: Int? = nil,
         transferOffset: Int? = nil,
         withdrawOffset: Int? = nil,
         depositOffset: Int? = nil) {
        var store: [String: String] = [
            WalletHistoryContextKeys.ignoringIds: ignoringIds.joined(separator: ",")
        ]

        if let remoteOffset = remoteOffset {
            store[WalletHistoryContextKeys.remoteOffset] = String(remoteOffset)
        }

        if let transferOffset = transferOffset {
            store[WalletHistoryContextKeys.transferOffset] = String(transferOffset)
        }

        if let withdrawOffset = withdrawOffset {
            store[WalletHistoryContextKeys.withdrawOffset] = String(withdrawOffset)
        }

        if let depositOffset = depositOffset {
            store[WalletHistoryContextKeys.depositOffset] = String(depositOffset)
        }

        self = store
    }

    private func offsetForKey(_ key: String) -> Int? {
        if let valueString = self[key], let value = Int(valueString) {
            return value
        } else {
            return nil
        }
    }
}
