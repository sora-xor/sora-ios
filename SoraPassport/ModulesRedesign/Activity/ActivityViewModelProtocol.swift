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
import SoraUIKit
import RobinHood

import UIKit

typealias ActivityDataSource = UITableViewDiffableDataSource<ActivitySection, ActivitySectionItem>
typealias ActivitySnapshot = NSDiffableDataSourceSnapshot<ActivitySection, ActivitySectionItem>

protocol ActivityViewProtocol: ControllerBackedProtocol {
    func stopAnimating()
    func resetPagination()
    func startPaginationLoader()
    func stopPaginationLoader()
}

protocol ActivityViewModelProtocol: SoramitsuTableViewPaginationHandlerProtocol {
    var snapshotPublisher: Published<ActivitySnapshot>.Publisher { get }
    var title: String { get set }
    var isNeedCloseButton: Bool { get }
    var setupEmptyLabel: (() -> Void)? { get set }
    var setupErrorContent: (() -> Void)? { get set }
    var hideErrorContent: (() -> Void)? { get set }
    func viewDidLoad()
    /// The screen is about to be shown, for the first time or again.
    func viewWillAppear()
    func updateContent()
    func didSelect(with item: ActivitySectionItem)
    func headerText(for section: Int) -> String?
    func isNeedHeader(for section: Int) -> Bool
    func resetPagination()
}
