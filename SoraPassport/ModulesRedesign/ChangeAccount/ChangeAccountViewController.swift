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
import Anchorage
import SoraFoundation
import SoraUIKit
import SoraUI

final class ChangeAccountViewController: SoramitsuViewController {

    enum Mode {
        case view
        case edit

        var title: String {
            switch self {
            case .view:
                return R.string.localizable.commonEdit(preferredLanguages: .currentLocale)
            case .edit:
                return R.string.localizable.commonDone(preferredLanguages: .currentLocale)
            }
        }

        var action: Selector {
            switch self {
            case .view:
                return #selector(onEdit)
            case .edit:
                return #selector(onDone)
            }
        }

        var actionTitle: String {
            switch self {
            case .view:
                return R.string.localizable.accountAdd(preferredLanguages: .currentLocale)
            case .edit:
                return R.string.localizable.backupAccountTitle(preferredLanguages: .currentLocale)
            }
        }

        var actionIcon: UIImage? {
            switch self {
            case .view:
                return R.image.iconPlus()
            case .edit:
                return nil
            }
        }
    }
    
    private struct Constants {
        static let inset: CGFloat = 16
    }

    var presenter: ChangeAccountPresenterProtocol?

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sectionHeaderHeight = 0
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    private lazy var tableBg: SoramitsuView = {
        let view = SoramitsuView(frame: .zero)
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        view.sora.shadow = .default
        return view
    }()

    private lazy var actionButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .bleached(.primary))
        button.sora.leftImage = R.image.iconPlus()
        button.sora.cornerRadius = .circle
        button.sora.shadow = .small
        button.addTarget(nil, action: #selector(onAction), for: .touchUpInside)
        return button
    }()

    private var viewModel: [AccountMenuItem] = []
    private var tableConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        presenter?.reload()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        presenter?.endUpdating()
    }
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        
        navigationItem.largeTitleDisplayMode = .never
        addCloseButton()
        
        tableBg.addSubview(tableView)
        view.addSubview(tableBg)
        view.addSubview(actionButton)
    }
    
    private func setupConstraints() {
        tableBg.horizontalAnchors == view.horizontalAnchors + Constants.inset
        tableBg.topAnchor == view.soraSafeTopAnchor
        tableConstraint = tableBg.heightAnchor.constraint(equalToConstant: 0)
        tableConstraint?.isActive = true
        
        tableView.edgeAnchors == tableBg.edgeAnchors

        actionButton.horizontalAnchors == view.horizontalAnchors + Constants.inset
        actionButton.topAnchor == tableBg.bottomAnchor + Constants.inset
    }

    private func setupNavbarButton(mode: Mode) {

        let button = UIBarButtonItem(
            title: mode.title,
            style: .plain,
            target: self,
            action: mode.action
        )
        button.setTitleTextAttributes(
            [ .font: FontType.textBoldS.font, .foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary)],
            for: .normal
        )
        button.setTitleTextAttributes(
            [ .font: FontType.textBoldS.font],
            for: .selected
        )
        navigationItem.leftBarButtonItem = button
    }

    private func setup(mode: Mode) {
        setupNavbarButton(mode: mode)
        actionButton.sora.title = mode.actionTitle
        actionButton.sora.leftImage = mode.actionIcon
        presenter?.set(mode: mode)
    }

    @objc private func onEdit() {
        setup(mode: .edit)
    }

    @objc private func onDone() {
        setup(mode: .view)
    }

    @objc private func onAction() {
        presenter?.onAction()
    }
}

extension ChangeAccountViewController: ChangeAccountViewProtocol {
    
    func update(with accountViewModels: [AccountMenuItem]) {
        self.viewModel = accountViewModels
        
        tableView.sora.sections = [SoramitsuTableViewSection(rows: viewModel)]
        
        let height = CGFloat(accountViewModels.count) * AccountMenuItem.itemHeight
        let maxHeight = view.safeAreaLayoutGuide.layoutFrame.height - 3 * Constants.inset - actionButton.sora.size.height
        
        tableConstraint?.constant = height < maxHeight ? height : maxHeight
        view.layoutSubviews()
    }
}

extension ChangeAccountViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable.commonAccount(preferredLanguages: languages)
        actionButton.sora.title = R.string.localizable.accountAdd(preferredLanguages: languages)
    }
}
