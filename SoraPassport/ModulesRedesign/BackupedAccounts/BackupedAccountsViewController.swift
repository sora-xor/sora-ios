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

import SoraUIKit
import Combine

final class BackupedAccountsViewController: SoramitsuViewController & BackupedAccountsViewProtocol {
    var viewModel: BackupedAccountsViewModelProtocol? {
        didSet {
            setupSubscriptions()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: BackupedAccountsDataSource = {
        BackupedAccountsDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .account(let item):
                let cell: BackupedAccountCell? = tableView.dequeueReusableCell(withIdentifier: "BackupedAccountCell",
                                                                              for: indexPath) as? BackupedAccountCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .space(let item):
                let cell: SoramitsuCell<SoramitsuTableViewSpaceView>? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuCell",
                                                                                                      for: indexPath) as? SoramitsuCell<SoramitsuTableViewSpaceView>
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .button(let item):
                let cell: SoramitsuButtonCell? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuButtonCell",
                                                                              for: indexPath) as? SoramitsuButtonCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(BackupedAccountCell.self, forCellReuseIdentifier: "BackupedAccountCell")
        tableView.register(SoramitsuButtonCell.self, forCellReuseIdentifier: "SoramitsuButtonCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SoramitsuCell")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        viewModel?.reload()
    }
    
    deinit {
        print("deinited")
    }

    private func setupView() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.selectAccountImport(preferredLanguages: .currentLocale)
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        soramitsuView.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: soramitsuView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: soramitsuView.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: soramitsuView.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: soramitsuView.centerYAnchor)
        ])
    }

    private func setupSubscriptions() {
        viewModel?.titlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.navigationItem.title = text
            }
            .store(in: &cancellables)
        
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension BackupedAccountsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }
        
        switch item {
        case .space: return 16
        default: return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .account(let item):
            viewModel?.didSelectAccount(with: item.accountAddress)
        default: break
        }
    }
}
