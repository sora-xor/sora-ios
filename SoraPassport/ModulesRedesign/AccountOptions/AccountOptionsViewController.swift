import Foundation
import SoraFoundation
import SoraUIKit
import Then
import Anchorage

final class AccountOptionsViewController: SoramitsuViewController {
    var presenter: AccountOptionsPresenterProtocol!

    private let stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 16
            $0.sora.cornerRadius = .large
            $0.sora.distribution = .fill
            $0.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            $0.isLayoutMarginsRelativeArrangement = true
        }
    }()
    
    private lazy var addressView: SoramitsuControl = {
        SoramitsuControl().then {
            $0.sora.cornerRadius = .max
            $0.sora.backgroundColor = .bgSurface
            $0.sora.shadow = .small
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.presenter.copyToClipboard()
            }
        }
    }()

    lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.accountAddress(preferredLanguages: .currentLocale).uppercased()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var addressLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var usernameField: InputField = {
        InputField().then {
            $0.sora.leftImage = R.image.profile.editName()
            $0.sora.state = .default
            $0.sora.titleLabelText = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
            $0.textField.returnKeyType = .done
            $0.textField.sora.placeholder = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
            $0.textField.sora.addHandler(for: .editingChanged) { [weak self] in
                self?.presenter.didUpdateUsername(self?.usernameField.textField.text ?? "")
            }
        }
    }()

    private lazy var passphraseButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .text(.primary)).then {
            
            $0.addTarget(nil, action: #selector(passphraseTapped), for: .touchUpInside)
        }
    }()

    private let optionsCard: Card  = {
        Card().then {
            $0.sora.cornerRadius = .max
        }
    }()

    private lazy var logoutButton: SoramitsuButton = {
        SoramitsuButton(size:.large, type: .tonal(.tertiary)).then {
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(logoutTapped), for: .touchUpInside)
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configure()
        addCloseButton()
        presenter.setup()
    }


    private func configure() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.accountOptions(preferredLanguages: .currentLocale)
        
        addressView.addSubviews(titleLabel, addressLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: addressView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: addressView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: addressView.topAnchor, constant: 24),
            
            addressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            addressLabel.leadingAnchor.constraint(equalTo: addressView.leadingAnchor, constant: 24),
            addressLabel.centerXAnchor.constraint(equalTo: addressView.centerXAnchor),
            addressLabel.bottomAnchor.constraint(equalTo: addressView.bottomAnchor, constant: -24),
        ])
        
        view.addSubview(stackView)
        
        stackView.addArrangedSubviews(usernameField, addressView, optionsCard, logoutButton)
        stackView.setCustomSpacing(12, after: usernameField)

        stackView.do {
            $0.topAnchor == view.soraSafeTopAnchor
            $0.horizontalAnchors == view.horizontalAnchors
        }

        let options = [
            MenuItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportAccountDetailsShowPassphrase(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.passPhrase()
                $0.addArrow()
                $0.addTapGesture { recognizer in
                    self.passphraseTapped()
                }
            }),
//Buisness logic not implemented yet, so hidden
            MenuItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportAccountDetailsShowRawSeed(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.seed()
                $0.addArrow()
                $0.addTapGesture { recognizer in
                    self.passphraseTapped()
                }
                $0.isHidden = true
            }),
            MenuItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportProtectionJsonTitle(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.export()
                $0.addArrow()
                $0.addTapGesture { recognizer in
                    self.passphraseTapped()
                }
                $0.isHidden = true
            }),
        ]

        usernameField.do {
            $0.sora.titleLabelText = R.string.localizable
                .personalInfoUsernameV1(preferredLanguages: languages)
        }

        optionsCard.do {
            $0.stackContents = options
            $0.headerText = R.string.localizable.exportAccountDetailsBackupOptions(preferredLanguages: languages).uppercased()
            $0.footerText = R.string.localizable.exportAccountDetailsBackupDescription(preferredLanguages: languages)
        }

        logoutButton.do {
            $0.sora.title = R.string.localizable.forgetAccount(preferredLanguages: languages)
        }
    }

    @objc
    func passphraseTapped() {
        presenter.showPassphrase()
    }

    @objc
    func logoutTapped() {
        presenter.doLogout()
    }
}

extension AccountOptionsViewController: AccountOptionsViewProtocol {
    func didReceive(username: String, hasEntropy: Bool) {
        self.usernameField.sora.text = username
    }
    
    func didReceive(address: String) {
        addressLabel.sora.text = address
    }
}


extension AccountOptionsViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable.exportAccountOptions(preferredLanguages: languages)

        usernameField.do {
            $0.sora.titleLabelText = R.string.localizable
                .personalInfoUsernameV1(preferredLanguages: languages)
        }

        optionsCard.do {
            $0.headerText = R.string.localizable.exportAccountDetailsBackupOptions(preferredLanguages: languages)
            $0.footerText = R.string.localizable.exportAccountDetailsBackupDescription(preferredLanguages: languages)
        }

        logoutButton.do {
            $0.sora.title = R.string.localizable.forgetAccount(preferredLanguages: languages)
        }
    }
}
