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
import SoraFoundation

protocol RedesignWalletViewProtocol: ControllerBackedProtocol {}

final class RedesignWalletViewController: SoramitsuViewController {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        // Clear: the tab bar controller draws the aurora behind every tab.
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.tableViewHeader = nil
        tableView.delaysContentTouches = true
        tableView.canCancelContentTouches = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 65, right: 0)
        if #available(iOS 15.0, *) {
              tableView.sectionHeaderTopPadding = 0
         }
        return tableView
    }()

    let viewModel: RedesignWalletViewModel
    /// The portfolio's table glue, from `viewDidLoad`.
    private var portfolioBinding: PortfolioTableBinding?

    init(viewModel: RedesignWalletViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()

        viewModel.reloadItem = { [weak self] items in
            DispatchQueue.main.async {
                guard let self = self else { return }
                Self.refresh(items: items, in: self.tableView)
            }
        }
        
        viewModel.setupItems = { [weak self] items in
            UIView.performWithoutAnimation {
                self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
                self?.tableView.layoutIfNeeded()
            }
            
        }

        viewModel.fetchAssets { [weak self] items in
            UIView.performWithoutAnimation {
                self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
                self?.tableView.layoutIfNeeded()
            }
        }

        portfolioBinding = PortfolioTableBinding(home: viewModel.portfolioHome, tableView: tableView, host: self)
    }

    // Live balance updates can arrive in a burst. Animating a transparent card
    // reload retains outgoing cell snapshots and overlays several sets of rows.
    static func refresh(items: [SoramitsuTableViewItemProtocol], in tableView: SoramitsuTableView) {
        UIView.performWithoutAnimation {
            for item in items {
                for section in tableView.sora.sections {
                    guard let row = section.rows.firstIndex(where: { $0.isEqual(item) }) else { continue }
                    // Preserve the data source for future dequeues as well as
                    // updating the visible cell. Most wallet items mutate in place.
                    if section.rows[row] !== item { section.rows[row] = item }
                    (tableView.cellForItem(item: item) as? SoramitsuTableViewCellProtocol)?
                        .set(item: item, context: section.context)
                    break
                }
            }
            // Rebinding avoids UITableView's outgoing reload snapshots. Settle
            // capability-driven height changes before leaving this scope.
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        tableView.reloadData()
        portfolioBinding?.safeAreaDidChange()
        viewModel.portfolioHome.viewWillAppear()
        // Settings (the Taira switch) or the selected account may have changed.
        viewModel.refreshNetworkRows()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        portfolioBinding?.safeAreaDidChange()
        viewModel.portfolioHome.viewDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.portfolioHome.viewDidDisappear()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        portfolioBinding?.safeAreaDidChange()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        // The portfolio's sky runs under the status bar.
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 40)
        ])
    }
}

extension RedesignWalletViewController: RedesignWalletViewProtocol {}

extension RedesignWalletViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        tableView.reloadData()
    }
}
