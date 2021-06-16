/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ModalPickerCellProtocol {
    associatedtype Model

    var checkmarked: Bool { get set }

    func bind(model: Model)
}
