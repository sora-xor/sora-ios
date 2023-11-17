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
        tableView.register(StakedCell.self, forCellReuseIdentifier: "StakedCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SoramitsuSpaceCell")
        return tableView
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
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
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .space(let item):
                let cell: SoramitsuCell<SoramitsuTableViewSpaceView>? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuSpaceCell",
                                                                                                      for: indexPath) as? SoramitsuCell<SoramitsuTableViewSpaceView>
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .staked(let item):
                let cell: StakedCell? = tableView.dequeueReusableCell(withIdentifier: "StakedCell",
                                                                      for: indexPath) as? StakedCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()

    init(viewModel: PoolDetailsViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
        setupSubscription()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        showLoading()
        
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
        view.addSubview(activityIndicator)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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

extension PoolDetailsViewController: PoolDetailsViewProtocol {
    
    func showLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.isHidden = false
            self?.activityIndicator.startAnimating()
        }
    }

    func hideLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.isHidden = true
            self?.activityIndicator.stopAnimating()
        }
    }
}

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
