/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol PersonalInfoCellDelegate: class {
    func didSelectNext(on cell: PersonalInfoCell)
    func didChangeValue(in cell: PersonalInfoCell)
}

@IBDesignable
final class PersonalInfoCell: UITableViewCell {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var textField: UITextField!

    @IBInspectable
    var normalColor: UIColor = .black {
        didSet {
            updateErrorState()
        }
    }

    @IBInspectable
    var errorColor: UIColor = .red {
        didSet {
            updateErrorState()
        }
    }

    @IBInspectable
    var disabledAlpha: CGFloat = 0.5 {
        didSet {
            updateEnabledState()
        }
    }

    var isError: Bool = false {
        didSet {
            updateErrorState()
        }
    }

    weak var delegate: PersonalInfoCellDelegate?

    var model: PersonalInfoViewModelProtocol?

    func bind(model: PersonalInfoViewModelProtocol) {
        self.model = model

        titleLabel.text = model.title
        textField.text = model.value

        updateEnabledState()
    }

    private func updateErrorState() {
        if titleLabel != nil {
            titleLabel.textColor = !isError ? normalColor : errorColor
        }
    }

    private func updateEnabledState() {
        guard let model = model else {
            return
        }

        if model.enabled {
            textField.alpha = 1.0
            titleLabel.alpha = 1.0
            textField.isEnabled = true
        } else {
            textField.alpha = disabledAlpha
            titleLabel.alpha = disabledAlpha
            textField.isEnabled = false
        }
    }

    @IBAction private func actionTextFieldChange(sender: AnyObject) {
        if let delegate = delegate {
            delegate.didChangeValue(in: self)
        }
    }
}

extension PersonalInfoCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        isError = false
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let model = model else {
            return false
        }

        if !model.didReceiveReplacement(string, for: range) {
            textField.text = model.value
            return false
        }

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let delegate = delegate {
            delegate.didSelectNext(on: self)
            return false
        } else {
            return true
        }
    }
}
