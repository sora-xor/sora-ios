import UIKit
import SoraUIKit

final class KYCEnterEmailView: UIView {
    
    private let continueButtonText = R.string.soraCard.commonSendLink(preferredLanguages: .currentLocale)
    private var state: BaseContinueButtonState = .disabled("")

    var onContinueButton: (() -> Void)?

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.text = R.string.soraCard.enterEmailDescription(preferredLanguages: .currentLocale)
        return label
    }()

    private(set) lazy var inputField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.soraCard.enterEmailInputFieldLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.soraCard.enterEmailInputFieldLabel(preferredLanguages: .currentLocale)
        view.sora.descriptionLabelText = R.string.soraCard.commonNoSpam(preferredLanguages: .currentLocale)
        view.sora.keyboardType = .emailAddress
        view.sora.textContentType = .emailAddress
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.configure(errorMessage: "")
            self?.configureContinueButton(isEmpty: !(view.sora.text?.isEmpty ?? true))
        }
        return view
    }()

    private lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.commonSendLink(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .fgSecondary,
            alignment: .center
        )
        button.sora.isEnabled = false
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self else { return }
            self.continueButton.sora.isEnabled = false
            self.updateButtonState(to: .disabled(self.continueButtonText))
            self.onContinueButton?()
        }
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(errorMessage: String) {
        inputField.sora.state = errorMessage.isEmpty ? .success : .fail
        inputField.sora.descriptionLabelText = errorMessage
    }

    private func setupInitialLayout() {

        addSubview(textLabel)
        addSubview(inputField)
        addSubview(continueButton)

        textLabel.snp.makeConstraints {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        inputField.snp.makeConstraints {
            $0.top.equalTo(textLabel.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.height.equalTo(76) // TODO: Ivan fix InputField constraints to have min content size
        }

        continueButton.snp.makeConstraints {
            $0.top.equalTo(inputField.snp.bottom).offset(28)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }
}

private extension KYCEnterEmailView {
    func configureContinueButton(isEmpty: Bool) {
        continueButton.sora.isEnabled = isEmpty
        let newState: BaseContinueButtonState = isEmpty ? .enabled(continueButtonText) : .disabled(continueButtonText)
        updateButtonState(to: newState)
    }
    
    func updateButtonState(to newState: BaseContinueButtonState) {
        state = newState
        state.apply(to: continueButton)
    }
}
