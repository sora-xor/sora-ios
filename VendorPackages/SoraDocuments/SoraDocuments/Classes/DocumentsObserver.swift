/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct DocumentsObserver: DocumentsObserverProtocol {
    public var block: DocumentsStorageSubscriptionBlock
    public var queue: DispatchQueue?
    public var changes: DocumentsStorageChanges

    public init(block: @escaping DocumentsStorageSubscriptionBlock,
                queue: DispatchQueue?,
                changes: DocumentsStorageChanges) {
        self.block = block
        self.queue = queue
        self.changes = changes
    }
}
