/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class DataProviderProxyTrigger: DataProviderTriggerProtocol {
    weak var delegate: DataProviderTriggerDelegate?

    func receive(event: DataProviderEvent) {}
}
