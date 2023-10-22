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
import SoraFoundation
import Combine

final class ExploreViewController: SoramitsuViewController, ControllerBackedProtocol {
    
    var viewModel: DiscoverViewModelProtocol? {
        didSet {
            setupSubscriptions()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: ExploreDataSource = {
        ExploreDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .assets(let item):
                let cell: ExploreAssetsCell? = tableView.dequeueReusableCell(withIdentifier: "ExploreAssetsCell",
                                                                             for: indexPath) as? ExploreAssetsCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .pools(let item):
                let cell: ExplorePoolsCell? = tableView.dequeueReusableCell(withIdentifier: "ExplorePoolsCell",
                                                                            for: indexPath) as? ExplorePoolsCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            }
        }
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(ExploreAssetsCell.self, forCellReuseIdentifier: "ExploreAssetsCell")
        tableView.register(ExplorePoolsCell.self, forCellReuseIdentifier: "ExplorePoolsCell")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        
        viewModel?.setup()
    }

    private func setupView() {
        navigationController?.navigationBar.prefersLargeTitles = true
        
        soramitsuView.sora.backgroundColor = .bgPage
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
    
    private func setupSubscriptions() {
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension ExploreViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        navigationItem.title = R.string.localizable.commonExplore(preferredLanguages: languages)
    }
}

extension ExploreViewController: UITableViewDelegate {}
