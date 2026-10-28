// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood
import UIKit
import SSFCloudStorage

typealias EnterPasswordDataSource = UITableViewDiffableDataSource<EnterPasswordSection, EnterPasswordSectionItem>
typealias EnterPasswordSnapshot = NSDiffableDataSourceSnapshot<EnterPasswordSection, EnterPasswordSectionItem>


protocol EnterPasswordViewProtocol: ControllerBackedProtocol {
    var viewModel: EnterPasswordViewModelProtocol? { get set }
    func showLoading()
    func hideLoading()
}

protocol EnterPasswordViewModelProtocol: AnyObject {
    var titlePublisher: Published<String>.Publisher { get }
    var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { get }

    func reload()
}

protocol EnterPasswordWireframeProtocol: Loadable {
    func openSuccessImport(importedAccountAddress: String, accounts: [OpenBackupAccount])
}
