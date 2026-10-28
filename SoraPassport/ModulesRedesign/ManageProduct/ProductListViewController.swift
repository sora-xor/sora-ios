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

final class ProductListViewController: SoramitsuViewController {

    private let searchController = UISearchController(searchResultsController: nil)

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sora.backgroundColor = .bgSurface
        tableView.sectionHeaderHeight = 0
        tableView.sora.cornerMask = .all
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sectionHeaderHeight = .zero
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        tableView.scrollViewDelegate = self
        return tableView
    }()
    
    private lazy var emptyStateLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.searchEmptyState(preferredLanguages: .currentLocale),
                                                      fontData: FontType.textM,
                                                      textColor: .fgPrimary,
                                                      alignment: .center)
        label.sora.isHidden = true
        return label
    }()

    var viewModel: Produtable

    init(viewModel: Produtable) {
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

        searchController.searchBar.placeholder = viewModel.searchBarPlaceholder
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        navigationItem.title = viewModel.navigationTitle

        viewModel.reloadItems = { [weak self] item in
            UIView.performWithoutAnimation {
                self?.tableView.reloadItems(items: item)
            }
        }

        viewModel.setupItems = { [weak self] items in
            guard let self else { return }
            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    self.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
                    self.emptyStateLabel.sora.isHidden = !(items.isEmpty && self.viewModel.isActiveSearch)
                }
            }
        }

        viewModel.setupNavigationBar = { [weak self] mode in
            guard let self = self else {
                return
            }
                
            self.navigationItem.rightBarButtonItem = mode == .edit ? nil : UIBarButtonItem(image: R.image.wallet.cross(),
                                                                                           style: .plain,
                                                                                           target: self,
                                                                                          action: #selector(self.crossButtonTapped))

            if mode == .edit || mode == .view {
                let button = UIBarButtonItem(title: mode == .edit ? R.string.localizable.commonDone(preferredLanguages: .currentLocale) : R.string.localizable.commonEdit(preferredLanguages: .currentLocale),
                                             style: .plain,
                                             target: self,
                                             action: mode == .edit ? #selector(self.doneTapped) : #selector(self.editTapped) )
                // Styled by the bar appearance (`NeonChrome`): no red text on bars.
                self.navigationItem.leftBarButtonItem = button
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
        }
        
        viewModel.dismiss = { [weak self] isNeedForce in
            DispatchQueue.main.async {
                if self?.presentedViewController == nil || isNeedForce {
                    self?.navigationItem.searchController?.isActive = false
                    self?.dismiss(animated: true)
                }
            }
        }
        
        viewModel.viewDidLoad()
    }

    @objc
    func editTapped() {
        viewModel.mode = .edit
        tableView.dragInteractionEnabled = true
    }

    @objc
    func doneTapped() {
        viewModel.mode = .view
        tableView.dragInteractionEnabled = false
    }
    
    @objc
    func crossButtonTapped() {
        viewModel.viewdismissed()
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

extension ProductListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

extension ProductListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = false
    }
}
