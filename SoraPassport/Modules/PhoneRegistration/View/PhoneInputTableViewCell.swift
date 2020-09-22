import UIKit
import SoraFoundation

protocol PhoneInputTableViewCellDelegate: class {
    func phoneInputCellDidChangeValue(_ cell: PhoneInputTableViewCell)
}

final class PhoneInputTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var phoneNumberTextField: UITextField!

    private(set) var viewModel: InputViewModelProtocol?

    weak var delegate: PhoneInputTableViewCellDelegate?

    func bind(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title
        phoneNumberTextField.text = viewModel.inputHandler.value
    }

    func startEditing() {
        phoneNumberTextField.becomeFirstResponder()
    }

    func endEditing() {
        phoneNumberTextField.resignFirstResponder()
    }

    @IBAction private func actionTextDidChange() {
        if phoneNumberTextField.text != viewModel?.inputHandler.value {
            phoneNumberTextField.text = viewModel?.inputHandler.value
        }

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

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, phoneNumberTextField.text != viewModel.inputHandler.value {
            phoneNumberTextField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}
