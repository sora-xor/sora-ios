/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class PhoneVerificationViewController: AccessoryViewController, AdaptiveDesignable {
	var presenter: PhoneVerificationPresenterProtocol!

    var viewModel: InputViewModelProtocol?

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var textField: UITextField!

    lazy private(set) var resendDelayTimeFormatter = MinuteSecondFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        beginCodeEditing()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        endCodeEditing()
    }

    private func updateCodeDisplay() {
        guard let viewModel = viewModel else {
            return
        }

        textField.text = viewModel.inputHandler.value

        accessoryView?.isActionEnabled = viewModel.inputHandler.completed
    }

    override func setupLocalization() {
        super.setupLocalization()

        let languages = localizationManager?.selectedLocale.rLanguages

        title = R.string.localizable
            .verificationTitle(preferredLanguages: languages)
        titleLabel.text = R.string.localizable
            .verificationEnterCodeFromSms(preferredLanguages: languages)
    }

    // MARK: Keyboard

    private func beginCodeEditing() {
        textField.becomeFirstResponder()
    }

    private func endCodeEditing() {
        textField.resignFirstResponder()
    }

    // MARK: Actions

    override func actionAccessory() {
        guard let viewModel = viewModel else {
            return
        }

        endCodeEditing()

        presenter.process(viewModel: viewModel)
    }

    @IBAction func actionTextFieldDidChange() {
        if textField.text != viewModel?.inputHandler.value {
            textField.text = viewModel?.inputHandler.value
        }
    }

    @objc func actionResend() {
        endCodeEditing()
        presenter.resendCode()
    }
}

extension PhoneVerificationViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        guard let viewModel = viewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        accessoryView?.isActionEnabled = viewModel.inputHandler.completed

        return shouldApply
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        endCodeEditing()

        return false
    }
}

extension PhoneVerificationViewController: PhoneVerificationViewProtocol {
    func didReceive(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel

        updateCodeDisplay()
    }

    func didUpdateResendRemained(delay: TimeInterval) {
        let languages = localizationManager?.selectedLocale.rLanguages

        if delay > 0.0 {
            do {
                let timeString = try resendDelayTimeFormatter.string(from: delay)
                accessoryView?.title = R.string.localizable
                    .verificationRequestNewCodeTime(timeString, preferredLanguages: languages)
            } catch {
                accessoryView?.title = R.string.localizable
                    .verificationRequestNewCodeTime("", preferredLanguages: languages)
            }

        } else {
            let title = R.string.localizable.verificationResendCode(preferredLanguages: languages)
            let resendButton = accessoryViewFactory
                .createActionTitleView(with: title,
                                       target: self,
                                       actionHandler: #selector(actionResend))
            accessoryView?.titleView = resendButton
        }
    }
}
