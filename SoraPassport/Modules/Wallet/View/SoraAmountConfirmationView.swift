import CommonWallet
import SoraFoundation
import SoraUI
import Foundation
import UIKit

final class SoraAmountConfirmationView: BaseAmountInputView, WalletFormBordering {
    var contentInsets: UIEdgeInsets = .zero

    @IBOutlet private(set) var borderedView: BorderedContainerView!
    @IBOutlet private(set) var amountField: UITextField!
    @IBOutlet private(set) var amountLabel: UILabel!

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
            borderedView.borderType = newValue
        }
    }

    override var isFirstResponder: Bool {
        return amountField.isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        return amountField.resignFirstResponder()
    }

    override func awakeFromNib() {
        amountField.font = UIFont.styled(for: .paragraph2, isBold: true).withSize(18)
        amountLabel.font = UIFont.styled(for: .title1).withSize(15)
        amountLabel.text = R.string.localizable.transactionAmountTitle(preferredLanguages:             LocalizationManager.shared.selectedLocale.rLanguages)
    }

    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel
        inputViewModel.observable.add(observer: self)
        amountField.text = inputViewModel.displayAmount

        let locale = LocalizationManager.shared.selectedLocale
        self.amountField.attributedPlaceholder = NSAttributedString(string: R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages), attributes: [NSAttributedString.Key.foregroundColor : R.color.neumorphism.text()!]) 
    }

    func bind(viewModel: WalletFormSpentAmountModel) {
        amountField.text = viewModel.amount
        self.amountLabel.text = viewModel.title
        amountField.isEnabled = false
    }

    func bind(viewModel: WalletNewFormDetailsViewModel) {
        amountField.text = viewModel.details
        self.amountField.placeholder = viewModel.title
        amountField.isEnabled = false
    }

    func bind(viewModel: SoraTransactionAmountViewModel) {
        amountField.text = viewModel.details
        self.amountField.placeholder = viewModel.title
        amountField.isEnabled = false
    }

    // MARK: Private

    @IBAction private func actionTap(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .ended,
            borderedView.frame.contains(gestureRecognizer.location(in: borderedView)) {
            amountField.becomeFirstResponder()
        }
    }
}

extension SoraAmountConfirmationView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountField.text = inputViewModel?.displayAmount
    }
}
