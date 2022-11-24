/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraSwiftUI

final class WalletViewController: SoramitsuViewController {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sora.backgroundColor = .bgPage
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()

    let viewModel: WalletViewModel

    init(viewModel: WalletViewModel) {
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

        viewModel.reloadItem = { [weak self] item in
            self?.tableView.reloadItems(items: [ item ])
        }

        viewModel.fetchAssets { [weak self] items in
            self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.updateAssets()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .bgPage
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
}
