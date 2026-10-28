/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

public typealias TapableClosure = () -> Void

public protocol TapableProtocol {
    var action: TapableClosure? { get }
}
