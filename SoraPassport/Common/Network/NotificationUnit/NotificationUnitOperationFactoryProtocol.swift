/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

protocol NotificationUnitOperationFactoryProtocol: class {
    func userRegistrationOperation(_ urlTemplate: String, info: NotificationUserInfo) -> NetworkOperation<Bool>
    func tokenExchangeOperation(_ urlTemplate: String, info: TokenExchangeInfo) -> NetworkOperation<Bool>
    func permissionEnableOperation(_ urlTemplate: String, decentralizedIds: [String]) -> NetworkOperation<Bool>
}
