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

import SoraUIKit

protocol ProfileLoginViewProtocol: ControllerBackedProtocol {
    var presenter: ProfileLoginPresenterProtocol? { get set }
    func update(model: ProfileLoginModel)
}

final class ProfileLoginView: SoramitsuViewController & ProfileLoginViewProtocol {
    var presenter: ProfileLoginPresenterProtocol?
    private var model: ProfileLoginModel?

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        addCloseButton()
        setupView()
        setupConstraints()
        presenter?.reload()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func update(model: ProfileLoginModel) {
        if self.model == nil {
            tableView.sora.sections = model.sections
        } else {
            var allItems: [SoramitsuTableViewItemProtocol] = []
            model.sections.forEach({ allItems.append(contentsOf: $0.rows) })
            tableView.reloadItems(items: allItems)
        }
        navigationItem.title = model.title
        setNeedsStatusBarAppearanceUpdate()
        self.model = model
    }
}
