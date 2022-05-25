import UIKit

final class AlertInputFieldPresenter: NSObject {
    let viewModel: InputFieldViewModelProtocol

    init(viewModel: InputFieldViewModelProtocol) {
        self.viewModel = viewModel
    }

    private weak var doneAction: UIAlertAction?

    func present(from viewController: UIViewController) {
        let alertController = UIAlertController(title: viewModel.title,
                                                message: nil,
                                                preferredStyle: .alert)

        alertController.addTextField { [weak self] textField in
            guard let strongSelf = self else {
                return
            }

            textField.placeholder = strongSelf.viewModel.hint
            textField.delegate = strongSelf
            textField.autocapitalizationType = .none

            textField.addTarget(strongSelf,
                                action: #selector(strongSelf.actionTextChanged(textField:)),
                                for: .editingChanged)
        }

        let cancelAction = UIAlertAction(title: viewModel.cancelActionTitle, style: .cancel) { _ in
            self.viewModel.delegate?.inputFieldDidCancelInput(to: self.viewModel)
        }

        let doneAction = UIAlertAction(title: viewModel.doneActionTitle, style: .default) { _ in
            self.viewModel.delegate?.inputFieldDidCompleteInput(to: self.viewModel)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(doneAction)

        alertController.preferredAction = doneAction

        doneAction.isEnabled = viewModel.isComplete

        self.doneAction = doneAction

        viewController.present(alertController, animated: true, completion: nil)
    }

    @objc private func actionTextChanged(textField: UITextField) {
        if textField.text?.count != viewModel.value.count {
            /*
             * prevent app from crash if text field changes without
             * notifying delegate (like smart replacement)
            */

            textField.text = viewModel.value
        }
    }
}

extension AlertInputFieldPresenter: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        defer {
            doneAction?.isEnabled = viewModel.isComplete
        }

        if !viewModel.didReceive(replacement: string, in: range) {
            textField.text = viewModel.value
            return false
        }

        return true
    }
}
