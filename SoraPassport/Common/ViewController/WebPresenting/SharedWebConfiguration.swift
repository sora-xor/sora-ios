/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import WebKit

final class SharedWebConfiguration {
    static let processPool = WKProcessPool()

    static var configuration: WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool

        return configuration
    }
}
