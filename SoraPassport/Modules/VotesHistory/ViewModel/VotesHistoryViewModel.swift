/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum VotesHistoryItemType {
    case increase
    case decrease
}

protocol VotesHistoryItemViewModelProtocol: class {
    var title: String { get }
    var amount: String { get }
    var type: VotesHistoryItemType { get }
}

protocol VotesHistorySectionViewModelProtocol: class {
    var title: String { get }
    var items: [VotesHistoryItemViewModelProtocol] { get }
}

final class VotesHistorySectionViewModel: VotesHistorySectionViewModelProtocol {
    var title: String
    var items: [VotesHistoryItemViewModelProtocol]

    init(title: String, items: [VotesHistoryItemViewModelProtocol]) {
        self.title = title
        self.items = items
    }
}

final class VotesHistoryItemViewModel: VotesHistoryItemViewModelProtocol {
    var title: String
    var amount: String
    var type: VotesHistoryItemType

    init(title: String, amount: String, type: VotesHistoryItemType) {
        self.title = title
        self.amount = amount
        self.type = type
    }
}
