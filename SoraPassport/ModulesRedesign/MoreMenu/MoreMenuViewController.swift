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
import SoraFoundation

final class MoreMenuViewController: SoramitsuViewController & MoreMenuViewProtocol {
    var presenter: MoreMenuPresenterProtocol?
    
    private lazy var dataSource: MoreMenuDataSource = {
        MoreMenuDataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "MoreMenuCell", for: indexPath) as? MoreMenuCell
            cell?.set(item: item, context: nil)
            return cell
        }
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The tab keeps this controller alive while account selection and PI
        // emergency capabilities can change elsewhere in the app. Rebuild the
        // snapshot before it becomes visible so disabled production routes are
        // not left in a stale menu.
        presenter?.reload()
    }

    private func setupView() {
        // Clear: the tab bar controller draws the aurora behind every tab.
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        soramitsuView.addSubview(tableView)
        
        tableView.register(MoreMenuCell.self, forCellReuseIdentifier: "MoreMenuCell")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: soramitsuView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: soramitsuView.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: soramitsuView.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: soramitsuView.centerYAnchor)
        ])
    }
    
    func set(title: String) {
        navigationItem.title = title
    }

    func update(snapshot: MoreMenuSnapshot) {
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func refreshNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        let window = navigationBar.superview
        navigationBar.removeFromSuperview()
        window?.addSubview(navigationBar)
    }
}


extension MoreMenuViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        item.onTap?()
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}
