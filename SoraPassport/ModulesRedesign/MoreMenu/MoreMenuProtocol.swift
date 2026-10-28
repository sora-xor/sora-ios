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

typealias MoreMenuDataSource = UITableViewDiffableDataSource<MoreMenuSection, MoreMenuItem>
typealias MoreMenuSnapshot = NSDiffableDataSourceSnapshot<MoreMenuSection, MoreMenuItem>


protocol MoreMenuViewProtocol: ControllerBackedProtocol {
    var presenter: MoreMenuPresenterProtocol? { get set }
    
    func set(title: String)
    func update(snapshot: MoreMenuSnapshot)
    func refreshNavigationBar()
}

protocol MoreMenuPresenterProtocol: AnyObject {
    var view: MoreMenuViewProtocol? { get set }
    
    func reload()
}

protocol MoreMenuWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable, WebPresentable {
    func showChangeAccountView(from view: MoreMenuViewProtocol?)
    func showSoraCard(from view: MoreMenuViewProtocol?)
    func showFriendsView(from view: MoreMenuViewProtocol?)
    func showNodes(from view: MoreMenuViewProtocol?)
    func showInformation(from view: MoreMenuViewProtocol?)
    func showAppSettings(from view: MoreMenuViewProtocol?)
    func showSecurity(from view: MoreMenuViewProtocol?)
}
