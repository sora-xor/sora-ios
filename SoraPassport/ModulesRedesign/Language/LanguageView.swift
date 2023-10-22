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
