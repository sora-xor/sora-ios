import Foundation
import SoraFoundation
import SoraUIKit
import Then
import Anchorage
import SSFCloudStorage

final class AccountOptionsViewController: SoramitsuViewController {
    var presenter: AccountOptionsPresenterProtocol!

    private lazy var scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 16
            $0.sora.cornerRadius = .large
            $0.sora.distribution = .fill
            $0.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            $0.isLayoutMarginsRelativeArrangement = true
            $0.translatesAutoresizingMaskIntoConstraints = false
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

        scrollView.addSubview(stackView)
        
        view.addSubviews(scrollView)
                
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        stackView.addArrangedSubviews(usernameField, addressView, optionsCard, logoutButton)
        stackView.setCustomSpacing(12, after: usernameField)

        usernameField.do {
            $0.sora.titleLabelText = R.string.localizable
                .personalInfoUsernameV1(preferredLanguages: languages)
        }

        optionsCard.do {
            $0.headerText = R.string.localizable.exportAccountDetailsBackupOptions(preferredLanguages: languages).uppercased()
            $0.footerText = R.string.localizable.exportAccountDetailsBackupDescription(preferredLanguages: languages)
        }

        logoutButton.do {
            $0.sora.title = R.string.localizable.forgetAccount(preferredLanguages: languages)
        }
        
        view.setNeedsLayout()
    }

    @objc
    func passphraseTapped() {
        presenter.showPassphrase()
    }

    @objc
    func rawSeedTapped() {
        presenter.showRawSeed()
    }

    @objc
    func jsoneTapped() {
        presenter.showJson()
    }

    @objc
    func logoutTapped() {
        presenter.doLogout()
    }
    
    func deleteBackup() {
        let title = R.string.localizable.deleteBackupAlertTitle(preferredLanguages: .currentLocale)
        let message = R.string.localizable.deleteBackupAlertDescription(preferredLanguages: .currentLocale)
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(
            title: R.string.localizable.commonCancel(preferredLanguages: .currentLocale),
            style: .cancel) { (_: UIAlertAction) -> Void in
            }
        let useAction = UIAlertAction(
            title: R.string.localizable.commonDelete(preferredLanguages: .currentLocale),
            style: .destructive) { [weak self] (_: UIAlertAction) -> Void in
                self?.presenter.deleteBackup()
            }
        alertView.addAction(useAction)
        alertView.addAction(cancelAction)
        
        present(alertView, animated: true)
    }
}

extension AccountOptionsViewController: AccountOptionsViewProtocol {
    func didReceive(username: String, hasEntropy: Bool) {
        self.usernameField.sora.text = username
    }
    
    func didReceive(address: String) {
        addressLabel.sora.text = address
    }
    
    func setupOptions(with backUpState: BackupState) {
        let options = [
            AccountOptionItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportAccountDetailsShowPassphrase(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.passPhrase()
                $0.addArrow()
                $0.addTapGesture { [weak self] recognizer in
                    self?.passphraseTapped()
                }
            }),
            AccountOptionSeparator(),
            AccountOptionItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportAccountDetailsShowRawSeed(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.seed()
                $0.addArrow()
                $0.addTapGesture { [weak self] recognizer in
                    self?.rawSeedTapped()
                }
            })
        ]

        optionsCard.stackContents = options
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


extension AccountOptionsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -200 {
            close()
        }
    }
}
