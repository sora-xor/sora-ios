import UIKit
import SoraFoundation
import SoraUI

final class UsernameSetupViewController: UIViewController {
    var presenter: UsernameSetupPresenterProtocol!

    @IBOutlet private var inputField: AnimatedTextField!
    @IBOutlet private var hintLabel: UILabel!
    @IBOutlet private var usernameLabel: UILabel!
    @IBOutlet private var nextButton: SoraButton!
    @IBOutlet private var privacyLabel: UILabel!

    @IBOutlet private var nextBottom: NSLayoutConstraint!

    private var isFirstLayoutCompleted: Bool = false

    lazy var termDecorator: AttributedStringDecoratorProtocol = {
        CompoundAttributedStringDecorator.legal(for: localizationManager?.selectedLocale)
    }()

    var legalData = LegalData(termsUrl: ApplicationConfig.shared.termsURL,
                          privacyPolicyUrl: ApplicationConfig.shared.privacyPolicyURL)

    private var viewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTextField()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()

            inputField.becomeFirstResponder()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    override func viewDidLayoutSubviews() {
        guard !isFirstLayoutCompleted else {
            return
        }

        isFirstLayoutCompleted = true

        if currentKeyboardFrame != nil {
            applyCurrentKeyboardFrame()
        }

        super.viewDidLayoutSubviews()
    }

    var privacyTitle: NSAttributedString? {
        let languages = localizationManager?.preferredLocalizations
        let attributedText =  R.string.localizable
            .tutorialTermsAndConditions1(preferredLanguages: languages)
            .styled(.paragraph2)
            .aligned(.center)

        return termDecorator.decorate(attributedString: attributedText)
    }

    private func configureTextField() {
        inputField.textField.returnKeyType = .done
        inputField.textField.textContentType = .nickname
        inputField.textField.autocapitalizationType = .none
        inputField.textField.autocorrectionType = .no
        inputField.textField.spellCheckingType = .no
        inputField.textField.font = UIFont.styled(for: .paragraph2)
        inputField.textField.textAlignment = .right
        inputField.delegate = self

        privacyLabel.numberOfLines = 0
        privacyLabel.textAlignment = .center
        privacyLabel.font = UIFont.styled(for: .paragraph2)
        privacyLabel.textColor = R.color.baseContentPrimary()
        privacyLabel.attributedText = privacyTitle
        privacyLabel.isUserInteractionEnabled = true
        privacyLabel.addGestureRecognizer(tapGestureRecognizer)

        hintLabel.font = UIFont.styled(for: .paragraph3)
        usernameLabel.font = UIFont.styled(for: .paragraph2)
    }

    private func updateActionButton() {
        guard let viewModel = viewModel else {
            return
        }

        nextButton.isEnabled = viewModel.inputHandler.completed
    }

    // MARK: Private

    @IBAction private func textFieldDidChange(_ sender: UITextField) {
        if viewModel?.inputHandler.value != sender.text {
            sender.text = viewModel?.inputHandler.value
        }

        updateActionButton()
    }

    @IBAction private func actionNext() {
        inputField.resignFirstResponder()

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

extension UsernameSetupViewController: AnimatedTextFieldDelegate {
    func animatedTextField(_ textField: AnimatedTextField,
                           shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool {
        guard let viewModel = viewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension UsernameSetupViewController: KeyboardViewAdoptable {
    var targetBottomConstraint: NSLayoutConstraint? { nextBottom }

    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat {
        if bottomInset > 0.0 {
            return -view.safeAreaInsets.bottom + 24
        } else {
            return 24
        }
    }
}

extension UsernameSetupViewController: UsernameSetupViewProtocol {
    func set(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel

        updateActionButton()
    }
}

extension UsernameSetupViewController: Localizable {
    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        title = R.string.localizable.create_account_title(preferredLanguages: languages)

        nextButton.title = R.string.localizable
            .transactionContinue(preferredLanguages: languages)
        nextButton.invalidateLayout()

        usernameLabel.text = R.string.localizable.personalInfoUsernameV1(preferredLanguages: languages)

        hintLabel.text = R.string.localizable.personalDetailsInfo(preferredLanguages: languages)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
