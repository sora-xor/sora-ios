/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol SelectionListViewProtocol: ControllerBackedProtocol {
    func didReload()
}

protocol SelectionListPresenterProtocol: class {
    var numberOfItems: Int { get }

    func item(at index: Int) -> SelectionListViewModelProtocol
    func selectItem(at index: Int)
}
