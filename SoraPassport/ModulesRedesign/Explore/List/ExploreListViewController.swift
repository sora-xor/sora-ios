// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import UIKit
import SoraUIKit

final class ExploreListViewController: SoramitsuViewController {

    private let searchController = UISearchController(searchResultsController: nil)

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sora.backgroundColor = .bgSurface
        tableView.sectionHeaderHeight = 0
        tableView.sora.cornerMask = .all
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        tableView.scrollViewDelegate = self
        return tableView
    }()

    var viewModel: Explorable

    init(viewModel: Explorable) {
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

        navigationItem.title = viewModel.navigationTitle

        viewModel.setupItems = { [weak self] items in
            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
                }
            }
        }

        viewModel.setupNavigationBar = { [weak self] leftBarButtonItem in
            guard let self = self else { return }
                
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.wallet.cross(),
                                                                     style: .plain,
                                                                     target: self,
                                                                     action: #selector(self.crossButtonTapped))
            
            self.navigationItem.leftBarButtonItem = leftBarButtonItem
        }
        
        viewModel.viewDidLoad()
    }
    
    @objc
    func crossButtonTapped() {
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}

extension ExploreListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

extension ExploreListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = false
    }
}
