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

import UIKit
import SoraUIKit
import SoraFoundation
import SnapKit

protocol YourReferrerViewInput: AnyObject {
    func setup(with models: [CellViewModel])
    func dismiss(with completion: @escaping () -> Void)
    func pop()
}

protocol YourReferrerViewOutput {
    func willMove()
}

final class YourReferrerViewController: SoramitsuViewController {
    
    var presenter: YourReferrerViewOutput
    private var models: [CellViewModel] = []
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorInset = .zero
        tableView.separatorColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.custom(uiColor: .clear))
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(
            YourReferrerCell.self,
            forCellReuseIdentifier: YourReferrerCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupHierarchy()
        setupLayout()
        applyLocalization()
        presenter.willMove()
    }
    
    init(presenter: YourReferrerViewOutput) {
        self.presenter = presenter
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        addCloseButton()
    }
    
    private func setupHierarchy() {
        view.addSubview(tableView)
    }
    
    private func setupLayout() {
        let tableViewLeadingOffset: CGFloat = 16
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.equalTo(view).offset(tableViewLeadingOffset)
            make.center.equalTo(view)
        }
    }
}

extension YourReferrerViewController: YourReferrerViewInput {
    func setup(with models: [CellViewModel]) {
        self.models = models
        tableView.reloadData()
    }
    
    func dismiss(with completion: @escaping () -> Void) {
        dismiss(animated: true, completion: completion)
    }
    
    func pop() {
        guard let navigationController = navigationController else { return }
        navigationController.popViewController(animated: true)
    }
}

extension YourReferrerViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = models[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: YourReferrerTableViewCell")
        }
        cell.bind(viewModel: models[indexPath.row])
        return cell
    }
}

extension YourReferrerViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        title = R.string.localizable.referralYourReferrer(preferredLanguages: languages)
    }
}

