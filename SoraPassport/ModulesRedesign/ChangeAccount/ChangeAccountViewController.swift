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
    private let switchProgress = UIView()
    private let switchSpinner = UIActivityIndicatorView(style: .large)
    private let switchStatus = WalletUX.label(WalletUX.text("Switching account…"), style: .body)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupConstraints()

        presenter?.reload()
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

        switchProgress.translatesAutoresizingMaskIntoConstraints = false
        switchProgress.backgroundColor = WalletUX.page.withAlphaComponent(0.96)
        switchProgress.accessibilityIdentifier = "wallet-account-switch-progress"
        switchProgress.accessibilityViewIsModal = true
        switchProgress.isHidden = true
        switchSpinner.color = WalletUX.foreground
        switchSpinner.hidesWhenStopped = true
        switchSpinner.accessibilityIdentifier = "wallet-account-switch-spinner"
        switchStatus.textAlignment = .center
        let status = UIStackView(arrangedSubviews: [switchSpinner, switchStatus])
        status.axis = .vertical
        status.spacing = 16
        status.translatesAutoresizingMaskIntoConstraints = false
        switchProgress.addSubview(status)
        view.addSubview(switchProgress)
        NSLayoutConstraint.activate([
            switchProgress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            switchProgress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            switchProgress.topAnchor.constraint(equalTo: view.topAnchor),
            switchProgress.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            status.centerXAnchor.constraint(equalTo: switchProgress.centerXAnchor),
            status.centerYAnchor.constraint(equalTo: switchProgress.centerYAnchor),
            status.leadingAnchor.constraint(greaterThanOrEqualTo: switchProgress.leadingAnchor, constant: 24),
            status.trailingAnchor.constraint(lessThanOrEqualTo: switchProgress.trailingAnchor, constant: -24)
        ])
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
        // Styled by the bar appearance (`NeonChrome`): no red text on bars.
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
    func setSwitchingAccount(_ switching: Bool) {
        switchProgress.isHidden = !switching
        tableView.isUserInteractionEnabled = !switching
        actionButton.isEnabled = !switching
        navigationItem.leftBarButtonItems?.forEach { $0.isEnabled = !switching }
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = !switching }
        isModalInPresentation = switching
        navigationController?.isModalInPresentation = switching
        if switching {
            switchProgress.backgroundColor = WalletUX.page.withAlphaComponent(0.96)
            switchSpinner.color = WalletUX.foreground
            switchStatus.textColor = WalletUX.foreground
            switchSpinner.startAnimating()
            UIAccessibility.post(notification: .announcement, argument: switchStatus.text)
        } else {
            switchSpinner.stopAnimating()
        }
    }

    func showAccountSwitchError() {
        let alert = UIAlertController(
            title: WalletUX.text("Couldn’t switch accounts"),
            message: WalletUX.text("Your current account is still selected. Please try again."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
        present(alert, animated: true)
    }
    
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
        switchStatus.text = WalletUX.text("Switching account…")
        navigationItem.title = R.string.localizable.commonAccount(preferredLanguages: languages)
        actionButton.sora.title = R.string.localizable.accountAdd(preferredLanguages: languages)
    }
}
