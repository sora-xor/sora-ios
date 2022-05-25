import UIKit
import SoraFoundation
import SoraUI

final class UsernameSetupViewController: UIViewController {
    enum Mode {
        case onboarding
        case editing
    }
    var mode: Mode = .onboarding {
        didSet {
            if isViewLoaded {
                setupLocalization()
            }
        }
    }
    var presenter: UsernameSetupPresenterProtocol!

    @IBOutlet private var inputField: NeuTextField!
    @IBOutlet private var hintLabel: UILabel!
    @IBOutlet private var nextButton: NeumorphismButton!
    @IBOutlet private var privacyLabel: UILabel!

    @IBOutlet private var nextBottom: NSLayoutConstraint!

    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var centeringConstraint: NSLayoutConstraint!
    private var isFirstLayoutCompleted: Bool = false

    lazy var termDecorator: AttributedStringDecoratorProtocol = {
        CompoundAttributedStringDecorator.legal(for: localizationManager?.selectedLocale)
    }()

    var legalData = LegalData(termsUrl: ApplicationConfig.shared.termsURL,
                          privacyPolicyUrl: ApplicationConfig.shared.privacyPolicyURL)

    private var viewModel: InputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
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
            .tutorialTermsAndConditionsV4(preferredLanguages: languages)
            .styled(.paragraph2)
            .aligned(.center)

        return termDecorator.decorate(attributedString: attributedText)
    }

    private func configure() {
        view.backgroundColor = R.color.neumorphism.base()
        if UIScreen.main.bounds.size.height <= 667 {
            centeringConstraint.constant = -180
        }
        configureButton()
        configureTextField()
        setupLocalization()
    }

    private func configureButton() {
        nextButton.color = R.color.neumorphism.tint()!
        nextButton.font = UIFont.styled(for: .button)
    }

    private func configureTextField() {
        inputField.returnKeyType = .done
        inputField.textContentType = .nickname
        inputField.autocapitalizationType = .none
        inputField.autocorrectionType = .no
        inputField.spellCheckingType = .no
        inputField.keyboardType = .alphabet
        inputField.delegate = self

        privacyLabel.numberOfLines = 0
        privacyLabel.textAlignment = .center
        privacyLabel.attributedText = privacyTitle
        privacyLabel.isUserInteractionEnabled = true
        privacyLabel.addGestureRecognizer(tapGestureRecognizer)

        hintLabel.textColor = R.color.neumorphism.textDark()!
        hintLabel.font = UIFont.styled(for: .paragraph3)
    }
    
    // MARK: Private

    @IBAction private func textFieldDidChange(_ sender: UITextField) {
        if viewModel?.inputHandler.value != sender.text {
            sender.text = viewModel?.inputHandler.value
        }
    }

    @IBAction private func actionNext() {
        inputField.resignFirstResponder()
        presenter.userName = inputField.text
        if mode == .editing {
            navigationController?.popViewController(animated: true)
        } else {
            presenter.proceed()
        }
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

extension UsernameSetupViewController: SoraTextDelegate {

    func soraTextField(_ textField: NeuTextField,
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

    func soraTextFieldShouldReturn(_ textField: NeuTextField) -> Bool {
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
    }
}

extension UsernameSetupViewController: Localizable {
    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations

        inputField.placeholderText = R.string.localizable.personalInfoUsernameV1(preferredLanguages: languages)

        switch mode {
        case .onboarding:
            title = R.string.localizable.create_account_title(preferredLanguages: languages).capitalized
            privacyLabel.attributedText = privacyTitle
        case .editing:
            title = R.string.localizable.personalInfoUsernameV1(preferredLanguages: languages).capitalized
            privacyLabel.attributedText = nil
            if let name = presenter.userName {
                inputField.text = name
            }
        }
        nextButton.setTitle(R.string.localizable.transactionContinue(preferredLanguages: languages), for: .normal)
        hintLabel.text = R.string.localizable.personalDetailsInfo(preferredLanguages: languages)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
