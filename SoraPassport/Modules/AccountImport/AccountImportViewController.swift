import UIKit
import SoraKeystore
import SoraFoundation
import SoraUI

final class AccountImportViewController: UIViewController {
    private struct Constants {
        static let advancedFullHeight: CGFloat = 220.0
        static let advancedTruncHeight: CGFloat = 152.0
    }

    var presenter: AccountImportPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!

    @IBOutlet private var usernameLabel: UILabel!
    @IBOutlet private var privacyLabel: UILabel!

    @IBOutlet private var usernameTextField: NeuTextField!
    @IBOutlet private var mnemonicTextView: NeuTextView!

    @IBOutlet private var nextButton: NeumorphismButton!

    @IBOutlet private var warningView: UIView!
    @IBOutlet private var warningLabel: UILabel!

    private var derivationPathModel: InputViewModelProtocol?
    private var usernameViewModel: InputViewModelProtocol?
    private var passwordViewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?

    lazy var termDecorator: AttributedStringDecoratorProtocol = {
        CompoundAttributedStringDecorator.legal(for: localizationManager?.selectedLocale)
    }()

    var legalData = LegalData(termsUrl: ApplicationConfig.shared.termsURL,
                          privacyPolicyUrl: ApplicationConfig.shared.privacyPolicyURL)

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(type: .push,
                                                        duration: 0.35,
                                                        subtype: .fromBottom,
                                                        curve: .easeOut)

    var advancedDismissalAnimator = TransitionAnimator(type: .push,
                                                       duration: 0.35,
                                                       subtype: .fromTop,
                                                       curve: .easeIn)

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
            mnemonicTextView.becomeFirstResponder()
        }

    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.baseBackground() }

        usernameTextField.returnKeyType = .done
        usernameTextField.textContentType = .nickname
        usernameTextField.autocapitalizationType = .none
        usernameTextField.autocorrectionType = .no
        usernameTextField.spellCheckingType = .no
        usernameTextField.keyboardType = .alphabet
        usernameTextField.delegate = self
        usernameTextField.addTarget(self, action: #selector(actionNameTextFieldChanged), for: .editingChanged)

        mnemonicTextView.delegate = self

        privacyLabel.numberOfLines = 0
        privacyLabel.textAlignment = .center
        privacyLabel.font = UIFont.styled(for: .paragraph2)
        privacyLabel.textColor = R.color.baseContentPrimary()
        privacyLabel.attributedText = privacyTitle
        privacyLabel.isUserInteractionEnabled = true
        privacyLabel.addGestureRecognizer(tapGestureRecognizer)

    }

    var privacyTitle: NSAttributedString? {
        let languages = localizationManager?.preferredLocalizations

        let baseText = R.string.localizable
            .tutorialTermsAndConditionsRecovery(preferredLanguages: languages)
        let spl = baseText.nonEmptyComponents(separatedBy: String.lokalizableSeparator)
        let result = spl.reduce("", {$0+$1})
        let attributedText = result.decoratedWith([:], adding: [.foregroundColor: R.color.baseContentQuaternary()!, .underlineStyle: NSUnderlineStyle.single.rawValue ], to: [spl[1], spl[3]])

        return attributedText.aligned(.center)
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable
            .recoveryTitleV2(preferredLanguages: locale.rLanguages).capitalized

        usernameTextField.placeholderText = R.string.localizable.personalInfoUsernameV1(preferredLanguages: locale.rLanguages)

        nextButton.setTitle(R.string.localizable.transactionContinue(preferredLanguages: locale.rLanguages), for: .normal)
        nextButton.color = R.color.neumorphism.tint()!
        nextButton.font = UIFont.styled(for: .button)
        nextButton.removeNeumorphismShadows()
    }

    private func updateNextButton() {
        var isEnabled: Bool = true

        if let viewModel = usernameViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(usernameTextField.text?.isEmpty ?? true)
        }

        if let viewModel = sourceViewModel, viewModel.inputHandler.required {
            let textViewActive = !mnemonicTextView.isHidden && !(mnemonicTextView.text ?? "").isEmpty
            isEnabled = isEnabled && textViewActive
        }

        nextButton?.isEnabled = isEnabled
    }

    @IBAction private func actionNameTextFieldChanged() {
        if usernameViewModel?.inputHandler.value != usernameTextField.text {
            usernameTextField.text = usernameViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @IBAction func actionTerms(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let location = gestureRecognizer.location(in: privacyLabel.superview)

            if location.x < privacyLabel.center.x {
                presenter.activateURL(legalData.termsUrl)
            } else {
                presenter.activateURL(legalData.privacyPolicyUrl)
            }
        }
    }

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(actionTerms(_:)))
    }()
}

extension AccountImportViewController: AccountImportViewProtocol {
    func setSource(type: AccountImportSource) {
        switch type {
        case .mnemonic:
            passwordViewModel = nil
            mnemonicTextView.isHidden = false

        case .seed:
            mnemonicTextView.isHidden = false

        case .keystore:
            mnemonicTextView.isHidden = true
            mnemonicTextView.text = nil
        }

        warningView.isHidden = true
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel

        mnemonicTextView.placeholderText = viewModel.placeholder
        mnemonicTextView.text = viewModel.inputHandler.value

        updateNextButton()
    }

    func setName(viewModel: InputViewModelProtocol) {
        usernameViewModel = viewModel

        usernameTextField.text = viewModel.inputHandler.value

        updateNextButton()
    }

    func setPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel

        updateNextButton()
    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {
        derivationPathModel = viewModel
    }

    func setUploadWarning(message: String) {
        warningLabel.text = message
        warningView.isHidden = false
    }
}

extension AccountImportViewController: SoraTextDelegate {

    func soraTextField(_ textField: NeuTextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === usernameTextField {
            viewModel = usernameViewModel
        } else {
            viewModel = passwordViewModel
        }

        guard let currentViewModel = viewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }

    func soraTextFieldShouldReturn(_ textField: NeuTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }

    func soraTextViewDidChange(_ textView: NeuTextView) {
        if textView.text != sourceViewModel?.inputHandler.value {
            textView.text = sourceViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    func soraTextView(_ textView: NeuTextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
        if text == String.returnKey {
            textView.resignFirstResponder()
            return false
        }

        guard let model = sourceViewModel else {
            return false
        }

        let shouldApply = model.inputHandler.didReceiveReplacement(text, for: range)

        if !shouldApply, textView.text != model.inputHandler.value {
            textView.text = model.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountImportViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if mnemonicTextView.isFirstResponder {
                targetView = mnemonicTextView
            } else if usernameTextField.isFirstResponder {
                targetView = usernameTextField
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(firstResponderView.frame,
                                                    from: firstResponderView.superview)

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension AccountImportViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
