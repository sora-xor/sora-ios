/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation


enum ContactListError: Error {
    case invalidIndexPath
}


enum ContactListState {
    case full
    case search
}

public protocol ContactSectionViewModelProtocol {
    var title: String? { get }
    var items: [WalletViewModelProtocol] { get }
}

public struct ContactSectionViewModel: ContactSectionViewModelProtocol {
    public let title: String?
    public let items: [WalletViewModelProtocol]

    public init(title: String?, items: [WalletViewModelProtocol]) {
        self.title = title
        self.items = items
    }
}

protocol ContactListViewModelProtocol {
    var contacts: [ContactSectionViewModelProtocol] { get }
    var found: [WalletViewModelProtocol] { get }
    var state: ContactListState { get }
    var isEmpty: Bool { get }
    var shouldDisplayEmptyState: Bool { get }
    var numberOfSections: Int { get }
    
    func numberOfItems(in section: Int) -> Int
    func title(for section: Int) -> String?
    
    subscript(indexPath: IndexPath) -> WalletViewModelProtocol? { get }
    
}
