/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import XNetworking
import CommonWallet

// MARK: - View

protocol OldNodesViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func setup(with models: [CellViewModel])
    func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)
}

// MARK: - Factory
//
protocol OldNodesViewFactoryProtocol: AnyObject {
    static func createView() -> OldNodesViewProtocol?
}
