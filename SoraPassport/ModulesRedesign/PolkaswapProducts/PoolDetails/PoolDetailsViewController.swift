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
import Combine

final class PoolDetailsViewController: SoramitsuViewController {

    private lazy var tableView: UITableView = {
        let tableView = SoramitsuTableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.custom(uiColor: .clear))
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionHeaderHeight = .zero
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        tableView.register(PoolDetailsCell.self, forCellReuseIdentifier: "PoolDetailsCell")
        tableView.register(FarmListCell.self, forCellReuseIdentifier: "FarmListCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SoramitsuSpaceCell")
        tableView.sora.cancelsTouchesOnDragging = true
        return tableView
    }()

    var viewModel: PoolDetailsViewModelProtocol? {
        didSet {
            setupSubscription()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: PoolDetailsDataSource = {
        PoolDetailsDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .details(let item):
                let cell: PoolDetailsCell? = tableView.dequeueReusableCell(withIdentifier: "PoolDetailsCell",
                                                                           for: indexPath) as? PoolDetailsCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .space(let item):
                let cell: SoramitsuCell<SoramitsuTableViewSpaceView>? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuSpaceCell",
                                                                                                      for: indexPath) as? SoramitsuCell<SoramitsuTableViewSpaceView>
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .staked(let item):
                let cell: FarmListCell? = tableView.dequeueReusableCell(withIdentifier: "FarmListCell",
                                                                      for: indexPath) as? FarmListCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            }
        }
    }()

    init(viewModel: PoolDetailsViewModelProtocol) {
        self.viewModel = viewModel
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSubscription()
        setupView()
        setupConstraints()
        
        navigationItem.title = R.string.localizable.poolDetails(preferredLanguages: .currentLocale)
        
        addCloseButton()
        
        viewModel?.dismiss = { [weak self] in
            DispatchQueue.main.async {
                if self?.presentedViewController == nil {
                    self?.dismiss(animated: true, completion: { [weak self] in
                        self?.viewModel?.dismissed()
                    })
                }
            }
        }
        
        viewModel?.viewDidLoad()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupSubscription() {
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension PoolDetailsViewController: PoolDetailsViewProtocol {}

extension PoolDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }
        
        switch item {
        case .space: return 8
        default: return UITableView.automaticDimension
        }
    }
}
