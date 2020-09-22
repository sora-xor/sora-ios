/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraFoundation

final class PersonalUpdateViewController: UIViewController {
	var presenter: PersonalUpdatePresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private(set) var models: [InputViewModelProtocol] = []

    private var keyboardHandler: KeyboardHandler?

    private var hasChanges: Bool = false

    var locale: Locale?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        configureSaveButton()
        setupLocalization()

        updateActionState()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        setupKeyboardHandler()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        clearKeyboardHandler()
    }

    private func configureTableView() {
        tableView.register(R.nib.personalInfoCell)
    }

    private func configureSaveButton() {
        let saveButton = UIBarButtonItem(title: R.string.localizable
            .commonSave(preferredLanguages: locale?.rLanguages),
                                         style: .plain,
                                         target: self,
                                         action: #selector(actionSave(sender:)))

        var normalTextAttributes = [NSAttributedString.Key: Any]()
        normalTextAttributes[.foregroundColor] = UIColor.barButtonTitle
        normalTextAttributes[.font] = UIFont.barButtonTitle

        saveButton.setTitleTextAttributes(normalTextAttributes, for: .normal)

        var disabledTextAttributes = [NSAttributedString.Key: Any]()
        disabledTextAttributes[.foregroundColor] = UIColor.barButtonTitle.withAlphaComponent(0.5)
        disabledTextAttributes[.font] = UIFont.barButtonTitle

        saveButton.setTitleTextAttributes(disabledTextAttributes, for: .disabled)

        navigationItem.rightBarButtonItem = saveButton
    }

    private func setupLocalization() {
        title = R.string.localizable.personalUpdateTitle(preferredLanguages: locale?.rLanguages)
    }

    // MARK: Keyboard

    func setupKeyboardHandler() {
        keyboardHandler = KeyboardHandler()
        keyboardHandler?.animateOnFrameChange = animateKeyboardChange
    }

    private func animateKeyboardChange(keyboardFrame: CGRect) {
        let localKeyboardFrame = view.convert(keyboardFrame, from: nil)

        let margin = tableView.frame.maxY - localKeyboardFrame.minY

        var contentInset = tableView.contentInset

        if margin > 0.0 {
            tableView.isScrollEnabled = true
            contentInset.bottom = margin
        } else {
            tableView.isScrollEnabled = false
            contentInset.bottom = 0.0
        }

        tableView.contentInset = contentInset
    }

    func clearKeyboardHandler() {
        keyboardHandler = nil
    }

    // MARK: Actions

    @objc private func actionSave(sender: AnyObject) {
        tableView.visibleCells.forEach { ($0 as? PersonalInfoCell)?.textField.resignFirstResponder() }

        presenter.save()
    }

    private func updateActionState() {
        guard let rightBarButtonItem = navigationItem.rightBarButtonItem else {
            return
        }

        rightBarButtonItem.isEnabled = hasChanges &&
            (models.first { $0.inputHandler.required && !$0.inputHandler.completed } == nil)
    }
}

extension PersonalUpdateViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.personalInfoCellId,
                                                 for: indexPath)!

        cell.bind(model: models[indexPath.row])
        cell.delegate = self

        return cell
    }
}

extension PersonalUpdateViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath) as? PersonalInfoCell {
            cell.textField.becomeFirstResponder()
        }
    }
}

extension PersonalUpdateViewController: PersonalInfoCellDelegate {
    func didSelectNext(on cell: PersonalInfoCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        cell.isError = !models[indexPath.row].inputHandler.completed

        let optionalNextIndex = ((indexPath.row + 1)..<models.count).first { models[$0].inputHandler.enabled }

        if let nextIndex = optionalNextIndex {
            let nextIndexPath = IndexPath(row: nextIndex, section: indexPath.section)
            guard let nextCell = tableView.cellForRow(at: nextIndexPath) as? PersonalInfoCell else {
                return
            }

            nextCell.textField.becomeFirstResponder()

            tableView.scrollToRow(at: nextIndexPath,
                                  at: .bottom,
                                  animated: true)
        } else {
            cell.textField.resignFirstResponder()
        }
    }

    func didChangeValue(in cell: PersonalInfoCell) {
        hasChanges = true

        updateActionState()
    }
}

extension PersonalUpdateViewController: PersonalUpdateViewProtocol {
    func didReceive(viewModels: [InputViewModelProtocol]) {
        models = viewModels
        tableView.reloadData()
    }

    func didStartSaving() {
        hasChanges = false

        updateActionState()
    }

    func didCompleteSaving(success: Bool) {
        hasChanges = !success

        updateActionState()
    }
}
