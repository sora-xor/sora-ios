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
import UIKit
import SoraUIKit

protocol ConfirmPassphraseViewProtocol: ControllerBackedProtocol {
    func setup(items: [SoramitsuTableViewItemProtocol])
    func update(items: [SoramitsuTableViewItemProtocol])
}

final class ConfirmPassphraseViewController: SoramitsuViewController, ControllerBackedProtocol {
    private var secretShield: WalletSensitiveScreenShield?

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    var viewModel: ConfirmPassphraseViewModelProtocol

    init(viewModel: ConfirmPassphraseViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = R.string.localizable.accountConfirmationTitleV2(preferredLanguages: .currentLocale)

        setupView()
        setupConstraints()
        viewModel.setup()
        secretShield = WalletSensitiveScreenShield(controller: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        secretShield?.refresh()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension ConfirmPassphraseViewController: ConfirmPassphraseViewProtocol {
    func setup(items: [SoramitsuTableViewItemProtocol]) {
        tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
    }
    
    func update(items: [SoramitsuTableViewItemProtocol]) {
        UIView.performWithoutAnimation {
            self.tableView.reloadItems(items: items)
        }
    }
}
