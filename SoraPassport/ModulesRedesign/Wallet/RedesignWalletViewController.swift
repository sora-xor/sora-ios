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

protocol RedesignWalletViewProtocol: ControllerBackedProtocol {}

final class RedesignWalletViewController: SoramitsuViewController {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .bgPage
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.tableViewHeader = nil
        tableView.delaysContentTouches = true
        tableView.canCancelContentTouches = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        if #available(iOS 15.0, *) {
              tableView.sectionHeaderTopPadding = 0
         }
        return tableView
    }()

    let viewModel: RedesignWalletViewModel

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
                self?.tableView.reloadItems(items: items )
            }
        }
        
        viewModel.setupItems = { [weak self] items in
            UIView.performWithoutAnimation {
                self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
            }
            
        }

        viewModel.fetchAssets { [weak self] items in
            UIView.performWithoutAnimation {
                self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
            }
        }
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .bgPage
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
