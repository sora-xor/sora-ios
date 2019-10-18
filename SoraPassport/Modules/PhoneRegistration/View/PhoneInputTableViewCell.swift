/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol PhoneInputTableViewCellDelegate: class {
    func phoneInputCellDidChangeValue(_ cell: PhoneInputTableViewCell)
}

final class PhoneInputTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var phoneNumberTextField: UITextField!

    private(set) var viewModel: PersonalInfoViewModelProtocol?

    weak var delegate: PhoneInputTableViewCellDelegate?

    func bind(viewModel: PersonalInfoViewModelProtocol) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title
        phoneNumberTextField.text = viewModel.value
    }

    func startEditing() {
        phoneNumberTextField.becomeFirstResponder()
    }

    func endEditing() {
        phoneNumberTextField.resignFirstResponder()
    }

    @IBAction private func actionTextDidChange() {
        delegate?.phoneInputCellDidChangeValue(self)
    }
}

extension PhoneInputTableViewCell: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let viewModel = viewModel else {
            return false
        }

        if !viewModel.didReceiveReplacement(string, for: range) {
            phoneNumberTextField.text = viewModel.value
            return false
        }

        return true
    }
}
