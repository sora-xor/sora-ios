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

typealias AccountImportedDataSource = UITableViewDiffableDataSource<AccountImportedSection, AccountImportedSectionItem>
typealias AccountImportedSnapshot = NSDiffableDataSourceSnapshot<AccountImportedSection, AccountImportedSectionItem>

protocol AccountImportedViewProtocol: ControllerBackedProtocol {
    var viewModel: AccountImportedViewModelProtocol? { get set }
}

protocol AccountImportedViewModelProtocol: AnyObject {
    var titlePublisher: Published<String>.Publisher { get }
    var snapshotPublisher: Published<AccountImportedSnapshot>.Publisher { get }
    func reload()
}

protocol AccountImportedWireframeProtocol {
    func showSetupPinCode()
    func showBackepedAccounts(accounts: [OpenBackupAccount])
    func dismiss(completion: (() -> Void)?)
}
