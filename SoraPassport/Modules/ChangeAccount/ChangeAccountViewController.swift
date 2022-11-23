/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage
import SoraFoundation

final class ChangeAccountViewController: UIViewController {
    
    private struct Style {
        static let rowHeight: CGFloat = 56
        static let separatorHeight: CGFloat = 1
    }

    var presenter: ChangeAccountPresenterProtocol!
    
    private var separatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.neumorphism.separator()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == Style.separatorHeight
        }
    }()
    
    private lazy var tableView: UITableView = {
        UITableView().then {
            $0.separatorInset = .zero
            $0.separatorColor = .clear
            $0.backgroundColor = .clear
            $0.rowHeight = Style.rowHeight
            $0.register(
                AccountTableViewCell.self,
                forCellReuseIdentifier: AccountTableViewCell.reuseIdentifier
            )
            $0.dataSource = self
            $0.delegate = self
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 170, right: 0)
        }
    }()
    
    private var createAccountButton: NeumorphismButton = {
        NeumorphismButton().then {
            if let color = R.color.neumorphism.tint() {
                $0.color = color
            }
            $0.heightAnchor == 56
            $0.tintColor = R.color.brandWhite()
            $0.font = UIFont.styled(for: .button)
            $0.addTarget(nil,
                         action: #selector(actionCreateAccount),
                         for: .touchUpInside)
        }
    }()

    private var importAccountButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.heightAnchor == 56
            $0.tintColor = R.color.brandWhite()
            $0.setTitleColor(R.color.neumorphism.buttonTextDark(), for: .normal)
            $0.font = UIFont.styled(for: .button)
            $0.addTarget(nil,
                         action: #selector(actionImportAccount),
                         for: .touchUpInside)
        }
    }()

    private(set) var accountViewModels: [AccountViewModelProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        presenter.setup()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.endUpdating()
    }
    
    private func configure() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "", style: .plain, target: nil, action: nil
        )
        
        view.backgroundColor = R.color.baseBackground()
        view.addSubview(tableView)
        view.addSubview(separatorView)
        view.addSubview(createAccountButton)
        view.addSubview(importAccountButton)

        tableView.do {
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor
            $0.bottomAnchor == view.bottomAnchor
            $0.topAnchor == separatorView.bottomAnchor
        }

        separatorView.do {
            $0.centerXAnchor == view.centerXAnchor
            $0.topAnchor == view.safeAreaLayoutGuide.topAnchor
        }

        createAccountButton.do {
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor + 12
            $0.bottomAnchor == importAccountButton.topAnchor - 8
        }

        importAccountButton.do {
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor + 12
            $0.bottomAnchor == view.safeAreaLayoutGuide.bottomAnchor - 40
        }
    }
    
    @objc func actionCreateAccount() {
        presenter?.createAccount()
    }

    @objc func actionImportAccount() {
        presenter?.importAccount()
    }
}

extension ChangeAccountViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accountViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: AccountTableViewCell.reuseIdentifier, for: indexPath
        ) as? AccountTableViewCell else {
            fatalError("Could not dequeue cell with identifier: ChangeAccountTableViewCell")
        }
        cell.bind(viewModel: accountViewModels[indexPath.row])
        return cell
    }
}

extension ChangeAccountViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectItem(at: indexPath.row)
    }
}

extension ChangeAccountViewController: ChangeAccountViewProtocol {
    func didLoad(accountViewModels: [AccountViewModelProtocol]) {
        self.accountViewModels = accountViewModels
        tableView.reloadData()
    }

    func update(with accountViewModels: [AccountViewModelProtocol]) {
        self.accountViewModels = accountViewModels
        tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
    }

    func scrollViewToBottom() {
        let indexPath = IndexPath(row: tableView.numberOfRows(inSection: tableView.numberOfSections - 1) - 1,
                                  section: tableView.numberOfSections - 1)

        let hasRowAtIndexPath = indexPath.section < tableView.numberOfSections &&
        indexPath.row < tableView.numberOfRows(inSection: indexPath.section)

        if !hasRowAtIndexPath { return }
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
}

extension ChangeAccountViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable.commonAccount(preferredLanguages: languages)

        createAccountButton.setTitle(R.string.localizable.create_account_title(preferredLanguages: languages),
                                     for: .normal)

        importAccountButton.setTitle(R.string.localizable.recoveryTitleV2(preferredLanguages: languages),
                                     for: .normal)
    }
}
