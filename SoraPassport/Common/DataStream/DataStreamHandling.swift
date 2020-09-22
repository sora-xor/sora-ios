/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol DataStreamHandling {
    func didReceive(remoteEvent: Data)
    func didReceiveSyncRequest()
}

protocol DataStreamProcessing {
    func process(event: DataStreamOneOfEvent)
    func processOutOfSync()
}
