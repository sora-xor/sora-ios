/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils

protocol WebSocketEngineFactoryProtocol {
    func createEngine(for url: URL, autoconnect: Bool) -> WebSocketEngine
}

final class WebSocketEngineFactory: WebSocketEngineFactoryProtocol {
    func createEngine(for url: URL, autoconnect: Bool) -> WebSocketEngine {
        WebSocketEngine(url: url)
//        WebSocketEngine(url: url,
//                        reachabilityManager: ReachabilityManager.shared,
//                        autoconnect: autoconnect, logger: Logger.shared)
    }
}
