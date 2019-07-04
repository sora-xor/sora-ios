/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class PersonalInfoViewController: UIViewController {
    private struct Constants {
        static let nextBottomMargin: CGFloat = 20.0
        static let tableMinimumBottomMargin: CGFloat = 8.0
    }

    var presenter: PersonalInfoPresenterProtocol!

    private(set) var models: [PersonalInfoViewModelProtocol] = []

    private var keyboardHandler: KeyboardHandler?

    @IBOutlet private var tableView: UITableView!

    @IBOutlet private var nextBottomMargin: NSLayoutConstraint!
    @IBOutlet private var nextHeight: NSLayoutConstraint!

    // MARK: Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()

        presenter.load()
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
        tableView.register(UINib(resource: R.nib.personalInfoCell),
                           forCellReuseIdentifier: R.reuseIdentifier.personalInfoCellId.identifier)
    }

    // MARK: Keyboard

    func setupKeyboardHandler() {
        keyboardHandler = KeyboardHandler()
        keyboardHandler?.animateOnFrameChange = animateKeyboardChange
    }

    private func animateKeyboardChange(keyboardFrame: CGRect) {
        let localKeyboardFrame = view.convert(keyboardFrame, from: nil)

        updateTableViewInset(with: localKeyboardFrame)

        if updateNextButtonPosition(with: localKeyboardFrame) {
            view.layoutIfNeeded()
        }
    }

    private func updateTableViewInset(with localKeyboardFrame: CGRect) {
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

    private func updateNextButtonPosition(with localKeyboardFrame: CGRect) -> Bool {
        var safeMaxY = view.bounds.maxY

        if #available(iOS 11.0, *) {
            safeMaxY = view.safeAreaLayoutGuide.layoutFrame.maxY
        }

        let newNextOriginY = localKeyboardFrame.origin.y - Constants.nextBottomMargin - nextHeight.constant

        let originLimitY = tableView.frame.maxY + Constants.tableMinimumBottomMargin
        if newNextOriginY >= originLimitY {
            nextBottomMargin.constant = max(0.0, safeMaxY - localKeyboardFrame.origin.y
                + Constants.nextBottomMargin)

            return true
        }

        let compactBottom = originLimitY + nextHeight.constant
        if compactBottom <= localKeyboardFrame.origin.y - Constants.tableMinimumBottomMargin {
            let bottom = max(0.0, safeMaxY - localKeyboardFrame.origin.y + Constants.tableMinimumBottomMargin)
            nextBottomMargin.constant = bottom
            return true
        }

        return false
    }

    func clearKeyboardHandler() {
        keyboardHandler = nil
    }

    // MARK: Actions

    @IBAction private func didSelectNextButton(sender: AnyObject) {
        validateAndRegister()
    }

    private func validateAndRegister() {
        tableView.visibleCells.forEach { ($0 as? PersonalInfoCell)?.textField.resignFirstResponder() }

        var isComplete = true
        for (index, model) in models.enumerated() {
            if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? PersonalInfoCell {
                cell.isError = !model.isComplete
            }

            if !model.isComplete {
                isComplete = false
                break
            }
        }

        if isComplete {
            presenter.register()
        }
    }
}

extension PersonalInfoViewController: UITableViewDataSource {
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

extension PersonalInfoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath) as? PersonalInfoCell {
            cell.textField.becomeFirstResponder()
        }
    }
}

extension PersonalInfoViewController: PersonalInfoCellDelegate {
    func didSelectNext(on cell: PersonalInfoCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        cell.isError = !models[indexPath.row].isComplete

        let optionalNextIndex = ((indexPath.row + 1)..<models.count).first { models[$0].enabled }

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

    func didChangeValue(in cell: PersonalInfoCell) {}
}

extension PersonalInfoViewController: PersonalInfoViewProtocol {
    func didReceive(viewModels: [PersonalInfoViewModelProtocol]) {
        models = viewModels
        tableView.reloadData()
    }
}
