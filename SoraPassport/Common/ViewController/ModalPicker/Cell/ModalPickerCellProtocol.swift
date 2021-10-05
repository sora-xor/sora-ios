/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit

protocol ModalPickerCellProtocol {
    associatedtype Model

    var checkmarked: Bool { get set }

    var toggle: UISwitch? { get }

    func bind(model: Model)
}

extension ModalPickerCellProtocol {
    var toggle: UISwitch? { nil }
}
