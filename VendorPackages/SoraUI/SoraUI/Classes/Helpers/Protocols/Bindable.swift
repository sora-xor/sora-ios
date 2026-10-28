/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

public protocol Bindable {
    func bind(viewModel: ViewModelProtocol)
}
