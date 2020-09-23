/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class PhoneRegistrationViewController: AccessoryViewController {
    enum Section: Int, CaseIterable {
        case phoneInput

        var rowHeight: CGFloat {
            switch self {
            case .phoneInput:
                return 100.0
            }
        }
    }

    var presenter: PhoneRegistrationPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private var phoneInputViewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()

        if let bottomInset = accessoryView?.contentView.frame.height {
            updateBottom(inset: bottomInset)
        }

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        beginPhoneEditing()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        endPhoneEditing()
    }

    private func configureTableView() {
        let footerFrame = CGRect(x: 0.0, y: 0.0, width: view.bounds.width, height: 1.0)
        tableView.tableFooterView = UIView(frame: footerFrame)

        tableView.register(R.nib.phoneInputTableViewCell)
    }

    override func setupLocalization() {
        super.setupLocalization()

        let languages = localizationManager?.selectedLocale.rLanguages

        title = R.string.localizable.phoneNumberTitle(preferredLanguages: languages)
        accessoryView?.title = R.string.localizable
            .phoneNumberSmsCodeWillBeSent(preferredLanguages: languages)
    }

    private func updateNextButton() {
        guard let phoneInputViewModel = phoneInputViewModel else {
            return
        }

        accessoryView?.isActionEnabled = phoneInputViewModel.inputHandler.completed
    }

    // MARK: Subclass

    override func updateBottom(inset: CGFloat) {
        var tableInset =  tableView.contentInset
        tableInset.bottom = inset
        tableView.contentInset = tableInset
    }

    override func actionAccessory() {
        endPhoneEditing()
        presenter.processPhoneInput()
    }

    // MARK: Keyboard Handling

    private func beginPhoneEditing() {
        let indexPath = IndexPath(row: 0, section: 0)
        if let phoneInputCell = tableView.cellForRow(at: indexPath) as? PhoneInputTableViewCell {
            phoneInputCell.startEditing()
        }
    }

    private func endPhoneEditing() {
        let indexPath = IndexPath(row: 0, section: 0)
        if let phoneInputCell = tableView.cellForRow(at: indexPath) as? PhoneInputTableViewCell {
            phoneInputCell.endEditing()
        }
    }
}

extension PhoneRegistrationViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }

        switch section {
        case .phoneInput:
            return phoneInputViewModel != nil ? 1 : 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section(rawValue: indexPath.section)!

        switch section {
        case .phoneInput:
            return configurePhoneInputCell(for: tableView, indexPath: indexPath)
        }
    }

    private func configurePhoneInputCell(for tableView: UITableView,
                                         indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.phoneInputCellId,
                                                 for: indexPath)!
        cell.delegate = self

        if let viewModel = phoneInputViewModel {
            cell.bind(viewModel: viewModel)
        }

        return cell
    }
}

extension PhoneRegistrationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else {
            return 0.0
        }

        return section.rowHeight
    }
}

extension PhoneRegistrationViewController: PhoneRegistrationViewProtocol {
    func didReceive(viewModel: InputViewModelProtocol) {
        phoneInputViewModel = viewModel

        tableView.reloadData()
        updateNextButton()
    }
}

extension PhoneRegistrationViewController: PhoneInputTableViewCellDelegate {
    func phoneInputCellDidChangeValue(_ cell: PhoneInputTableViewCell) {
        updateNextButton()
    }
}
