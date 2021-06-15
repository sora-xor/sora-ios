/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import Rswift

protocol SelectionItemViewProtocol: class {
    func bind(viewModel: SelectableViewModelProtocol)
}
