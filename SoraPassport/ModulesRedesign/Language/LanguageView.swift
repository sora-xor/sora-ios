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

import SoraUIKit
import Anchorage
import SoraFoundation

final class LanguageView: SoramitsuViewController & LanguageViewProtocol {
    
    private struct Constants {
        static let inset: CGFloat = 16
    }
    
    var presenter: LanguagePresenterProtocol?
    private var model: LanguageModel?
    
    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sectionHeaderHeight = 0
        tableView.sora.backgroundColor = .bgSurface
        tableView.sora.cornerMask = .top
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        setupNavBar()
        setupView()
        setupConstraints()
        presenter?.reload()
    }
    
    private func setupNavBar() {
        addCloseButton()
    }
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        tableView.leadingAnchor == view.leadingAnchor + Constants.inset
        tableView.trailingAnchor == view.trailingAnchor - Constants.inset
        tableView.topAnchor == view.safeAreaLayoutGuide.topAnchor
        tableView.bottomAnchor == view.bottomAnchor
    }
    
    func update(model: LanguageModel) {
        tableView.sora.sections = model.sections
        navigationItem.title = model.title
        self.model = model
    }
    
    func updateLayout() {
        let semanticContentAttribute: UISemanticContentAttribute = LocalizationManager.shared.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        navigationController?.navigationBar.semanticContentAttribute = semanticContentAttribute
    }
}
