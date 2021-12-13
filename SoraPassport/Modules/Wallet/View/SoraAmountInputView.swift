import CommonWallet
import SoraFoundation
import SoraUI
import Foundation

final class SoraAmountInputView: BaseAmountInputView, WalletFormBordering {
    var contentInsets: UIEdgeInsets = .zero

    @IBOutlet private(set) var borderedView: BorderedContainerView!
    @IBOutlet private(set) var assetLabel: UILabel!
    @IBOutlet private(set) var amountField: UITextField!
    @IBOutlet private(set) var keyboardIndicator: ActionTitleControl!

    private(set) var inputViewModel: AmountInputViewModelProtocol?

    var keyboardIndicatorSpacing: CGFloat = 8.0 {
        didSet {
            updateIndicatorState()
        }
    }

    var keyboardIndicatorIcon: UIImage? {
        didSet {
            updateIndicatorState()
        }
    }

    var keyboardIndicatorMode: KeyboardIndicatorDisplayMode = .editing {
        didSet {
            updateIndicatorState()
        }
    }

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
        self.assetLabel.font = UIFont.styled(for: .paragraph2, isBold: true)
        self.assetLabel.text = R.string.localizable.transactionAmountTitle()
        self.amountField.font = UIFont.styled(for: .paragraph2)
    }

    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel
        inputViewModel.observable.add(observer: self)
        amountField.text = inputViewModel.displayAmount

        let locale = LocalizationManager.shared.selectedLocale
        assetLabel.text = R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages)

    }

    func bind(viewModel: WalletFormSpentAmountModel) {
        amountField.text = viewModel.amount
        assetLabel.text = viewModel.title
        amountField.isEnabled = false
    }

    func bind(viewModel: WalletNewFormDetailsViewModel) {
        amountField.text = viewModel.details
        assetLabel.text = viewModel.title
        amountField.isEnabled = false
    }

    func bind(viewModel: SoraTransactionAmountViewModel) {
        amountField.text = viewModel.details
        assetLabel.text = viewModel.title
        amountField.isEnabled = false
    }

    // MARK: Private

    @IBAction private func actionControlDidChange() {
        if keyboardIndicator.isActivated {
            amountField.becomeFirstResponder()
        } else {
            amountField.resignFirstResponder()
        }
    }

    @IBAction private func actionTap(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .ended,
            borderedView.frame.contains(gestureRecognizer.location(in: borderedView)) {
            amountField.becomeFirstResponder()
        }
    }

    private func updateIndicatorState() {
        let shouldHide: Bool

        switch keyboardIndicatorMode {
        case .never:
            shouldHide = true
        case .editing:
            shouldHide = !amountField.isFirstResponder
        case .always:
            shouldHide = false
        }

        if !shouldHide {
            keyboardIndicator.imageView.image = keyboardIndicatorIcon
            keyboardIndicator.horizontalSpacing = keyboardIndicatorSpacing
        } else {
            keyboardIndicator.imageView.image = nil
            keyboardIndicator.horizontalSpacing = 0
        }
    }
}

extension SoraAmountInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountField.text = inputViewModel?.displayAmount
    }
}

extension SoraAmountInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        return inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateIndicatorState()
        keyboardIndicator.activate(animated: true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateIndicatorState()
        keyboardIndicator.deactivate(animated: true)
    }
}
