import SoraUIKit
import Anchorage
import FearlessUtils
import Combine

final class SetupPasswordCell: SoramitsuTableViewCell {
    private var cancellables: Set<AnyCancellable> = []
    private let input: PassthroughSubject<SetupPasswordItem.Input, Never> = .init()
    
    private weak var item: SetupPasswordItem? {
        didSet {
            guard let item = item else { return }
            let output = item.transform(input: input.eraseToAnyPublisher())
            output
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    switch event {
                    case .lowSecurityPassword:
                        let descriptionLabelText = R.string.localizable.createBackupWeakPassword(preferredLanguages: .currentLocale)
                        self?.setPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.setPasswordInputField.sora.state = .fail
                    case .securedPassword:
                        let descriptionLabelText = R.string.localizable.createBackupPasswordIsSecure(preferredLanguages: .currentLocale)
                        self?.setPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.setPasswordInputField.sora.state = .success
                    case .notMatchPasswords:
                        let descriptionLabelText = R.string.localizable.createBackupPasswordNotMatched(preferredLanguages: .currentLocale)
                        self?.confirmPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.confirmPasswordInputField.sora.state = .fail
                    case .matchedPasswords:
                        let descriptionLabelText = R.string.localizable.createBackupPasswordMatched(preferredLanguages: .currentLocale)
                        self?.confirmPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.confirmPasswordInputField.sora.state = .success
                    }
                }
                .store(in: &cancellables)
            
            item.$isButtonEnable
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.continueButton.sora.isEnabled = value
                }
                .store(in: &cancellables)
        }
    }

    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.localizable.backupPasswordTitle(preferredLanguages: .currentLocale)
        return label
    }()
    
    private lazy var setPasswordInputField: InputField = {
        let view = InputField()
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
        view.sora.state = .default
        view.sora.titleLabelText = R.string.localizable.createBackupSetPassword(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.localizable.createBackupSetPassword(preferredLanguages: .currentLocale)
        view.textField.returnKeyType = .next
        view.textField.isSecureTextEntry = true
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.input.send(.passwordChanged(view.textField.text ?? ""))
        }
        view.textField.sora.addHandler(for: .editingDidEndOnExit) { [weak self] in
            self?.confirmPasswordInputField.textField.becomeFirstResponder()
        }
        return view
    }()
    
    private lazy var confirmPasswordInputField: InputField = {
        let view = InputField()
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
        view.sora.state = .default
        view.sora.titleLabelText = R.string.localizable.exportJsonInputLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.localizable.exportJsonInputLabel(preferredLanguages: .currentLocale)
        view.textField.returnKeyType = .go
        view.textField.isSecureTextEntry = true
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.input.send(.confirmPasswordChanged(view.textField.text ?? ""))
        }
        return view
    }()
    
    private lazy var checkView: CheckView = {
        let view = CheckView(title: R.string.localizable.createBackupPasswordWarningText(preferredLanguages: .currentLocale))
        view.addTapGesture { [weak self] recognizer in
            guard let checkView = recognizer.view as? CheckView else { return }
            checkView.isSelected = !checkView.isSelected
            self?.input.send(.checkViewChanged(checkView.isSelected))
        }
        return view
    }()
    
    public lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.title = R.string.localizable.createBackupPasswordButtonText(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.horizontalOffset = 0
        button.sora.isEnabled = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.input.send(.setupPasswordButtonTapped)
        }
        return button
    }()
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("deinit")
    }
    
    private func setupView() {
        contentView.addSubview(containerView)
        containerView.addSubviews([
            descriptionLabel,
            setPasswordInputField,
            confirmPasswordInputField,
            checkView,
            continueButton
        ])
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            descriptionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            setPasswordInputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            setPasswordInputField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            setPasswordInputField.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            setPasswordInputField.heightAnchor.constraint(equalToConstant: 76),
            
            confirmPasswordInputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            confirmPasswordInputField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            confirmPasswordInputField.topAnchor.constraint(equalTo: setPasswordInputField.bottomAnchor, constant: 16),
            confirmPasswordInputField.heightAnchor.constraint(equalToConstant: 76),
            
            checkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            checkView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            checkView.topAnchor.constraint(equalTo: confirmPasswordInputField.bottomAnchor, constant: 16),
            
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            continueButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            continueButton.topAnchor.constraint(equalTo: checkView.bottomAnchor, constant: 24),
            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension SetupPasswordCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SetupPasswordItem else { return }
        setPasswordInputField.textField.becomeFirstResponder()
        self.item = item
    }
}
