/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class PhoneVerificationViewController: AccessoryViewController, AdaptiveDesignable {
	var presenter: PhoneVerificationPresenterProtocol!

    var viewModel: CodeInputViewModelProtocol?

    @IBOutlet private var textField: UITextField!

    lazy private(set) var resendDelayTimeFormatter = TimeFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.viewIsReady()
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

        textField.text = viewModel.code

        accessoryView?.isActionEnabled = viewModel.isComplete
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

        let result = viewModel.didReceiveReplacement(string, for: range)

        accessoryView?.isActionEnabled = viewModel.isComplete

        return result
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        endCodeEditing()

        return false
    }
}

extension PhoneVerificationViewController: PhoneVerificationViewProtocol {
    func didReceive(viewModel: CodeInputViewModelProtocol) {
        self.viewModel = viewModel

        updateCodeDisplay()
    }

    func didUpdateResendRemained(delay: TimeInterval) {
        if delay > 0.0 {
            do {
                let timeString = try resendDelayTimeFormatter.string(from: delay)
                accessoryView?.title = R.string.localizable.phoneVerificationCodeResendFormat(timeString)
            } catch {
                accessoryView?.title = R.string.localizable.phoneVerificationCodeResendFormat("")
            }

        } else {
            let title = R.string.localizable.phoneVerificationResendCodeMessage()
            let resendButton = accessoryViewFactory
                .createActionTitleView(with: title,
                                       target: self,
                                       actionHandler: #selector(actionResend))
            accessoryView?.titleView = resendButton
        }
    }
}
