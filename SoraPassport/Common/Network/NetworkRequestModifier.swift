/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import RobinHood

extension DARequestSigner: NetworkRequestModifierProtocol {
    public func modify(request: URLRequest) throws -> URLRequest {
        return try sign(urlRequest: request)
    }
}
