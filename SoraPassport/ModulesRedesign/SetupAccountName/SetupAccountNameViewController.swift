import UIKit
import SoraUIKit
import SoraFoundation

final class SetupAccountNameViewController: SoramitsuViewController {
    var presenter: UsernameSetupPresenterProtocol?
    
    private var viewModel: InputViewModelProtocol?
    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.onboardingCreateAccountDescription(preferredLanguages: .currentLocale)
        label.sora.alignment = .left
        return label
    }()
    
    private lazy var usernameField: InputField = {
        InputField().then {
            $0.textField.textContentType = .nickname
            $0.textField.autocapitalizationType = .none
            $0.textField.autocorrectionType = .no
            $0.textField.spellCheckingType = .no
            $0.textField.keyboardType = .alphabet
            $0.sora.state = .default
            $0.sora.titleLabelText = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
            $0.textField.returnKeyType = .done
            $0.textField.sora.placeholder = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
            $0.sora.descriptionLabelText = R.string.localizable.onboardingCreateAccountSubtitle(preferredLanguages: .currentLocale)
            $0.textField.delegate = self
        }
    }()

    private lazy var createAccountButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.title = R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.usernameField.textField.resignFirstResponder()
            self.presenter?.userName = self.usernameField.textField.text
            self.presenter?.proceed()
        }
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        title = R.string.localizable.onboardingCreateAccountTitle(preferredLanguages: .currentLocale)
        setupView()
        setupConstraints()
        presenter?.setup()
        usernameField.textField.becomeFirstResponder()
    }
    
    func setupView() {
        view.addSubview(containerView)
        containerView.addSubviews(subtitleLabel, usernameField, createAccountButton)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            usernameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            usernameField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            usernameField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            createAccountButton.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 24),
            createAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            createAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            createAccountButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension SetupAccountNameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }

    func textField(_ textField: UITextField,
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
}


extension SetupAccountNameViewController: UsernameSetupViewProtocol {
    func set(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel
    }
}
