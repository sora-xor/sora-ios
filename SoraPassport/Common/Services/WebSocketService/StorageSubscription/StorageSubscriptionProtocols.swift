/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol StorageChildSubscribing {
    var remoteStorageKey: Data { get }

    func processUpdate(_ data: Data?, blockHash: Data?)
}
