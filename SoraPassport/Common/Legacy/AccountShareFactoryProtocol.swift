/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import UIKit

public protocol AccountShareFactoryProtocol {
    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any]
}
