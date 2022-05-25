import CommonWallet
import SoraFoundation
import SoraUI
import Foundation
import UIKit

final class SoraAmountInputView: BaseAmountInputView, WalletFormBordering {
    var contentInsets: UIEdgeInsets = .zero

    @IBOutlet private(set) var borderedView: BorderedContainerView!
//    @IBOutlet private(set) var amountField: UITextField!
    @IBOutlet private(set) var amountInput: NeuTextField!

    private(set) var inputViewModel: AmountInputViewModelProtocol?

    override public var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = 56

        return size
    }

    var borderType: BorderType {
        get {
            borderedView.borderType
        }

        set {
//            borderedView.borderType = newValue
        }
    }

    override var isFirstResponder: Bool {
        return amountInput.isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        return amountInput.resignFirstResponder()
    }

    override func awakeFromNib() {
        amountInput.font = UIFont.styled(for: .paragraph2).withSize(29)
        amountInput.delegate = self
    }

    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel
        inputViewModel.observable.add(observer: self)
        amountInput.text = inputViewModel.displayAmount

        let locale = LocalizationManager.shared.selectedLocale
        self.amountInput.placeholderText = R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(viewModel: WalletFormSpentAmountModel) {
        amountInput.text = viewModel.amount
        amountInput.placeholderText = viewModel.title
        amountInput.isEnabled = false
    }

    func bind(viewModel: WalletNewFormDetailsViewModel) {
        amountInput.text = viewModel.details
        amountInput.placeholderText = viewModel.title
        amountInput.isEnabled = false
    }

    func bind(viewModel: SoraTransactionAmountViewModel) {
        amountInput.text = viewModel.details
        amountInput.placeholderText = viewModel.title
        amountInput.isEnabled = false
    }

    // MARK: Private

    @IBAction private func actionTap(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .ended,
            borderedView.frame.contains(gestureRecognizer.location(in: borderedView)) {
            amountInput.becomeFirstResponder()
        }
    }
}

extension SoraAmountInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountInput.text = inputViewModel?.displayAmount
        //cursor update?
    }
}

extension SoraAmountInputView: SoraTextDelegate {
    func soraTextField(_ textField: NeuTextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {

        return inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}
