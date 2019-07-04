/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood
@testable import SoraPassport

func clearDatabase(using service: CoreDataServiceProtocol) throws {
    try service.close()
    try service.drop()
}
