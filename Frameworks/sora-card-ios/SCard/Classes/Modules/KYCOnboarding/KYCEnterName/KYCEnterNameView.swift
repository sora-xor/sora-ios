import UIKit
import SoraUIKit

final class KYCEnterNameView: UIView {
    
    private let continueButtonText = R.string.soraCard.commonContinue(preferredLanguages: .currentLocale).capitalized
    private var state: BaseContinueButtonState = .disabled("")
    
    var onName: ((String) -> Void)?
    var onLastname: ((String) -> Void)?
    var onContinue: (() -> Void)?
   
    private(set) lazy var nameField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.soraCard.userRegistrationFirstNameInputFiledLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.soraCard.userRegistrationFirstNameInputFiledLabel(preferredLanguages: .currentLocale)
        view.sora.keyboardType = .alphabet
        view.sora.textContentType = .name
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.onName?(self?.nameField.sora.text ?? "")
        }
        return view
    }()

    private(set) lazy var lastnameField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.soraCard.userRegistrationLastNameInputFiledLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.soraCard.userRegistrationLastNameInputFiledLabel(preferredLanguages: .currentLocale)
        view.sora.keyboardType = .alphabet
        view.sora.textContentType = .familyName
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.onLastname?(self?.lastnameField.sora.text ?? "")
        }
        return view
    }()

    private lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.commonContinue(preferredLanguages: .currentLocale).capitalized,
            fontData: FontType.buttonM,
            textColor: .fgSecondary,
            alignment: .center
        )
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.continueButton.sora.isEnabled = false
            self?.onContinue?()
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
    
    func configure(isContinueButtonEnabled: Bool) {
        continueButton.sora.isEnabled = isContinueButtonEnabled
        updateButtonState(to: isContinueButtonEnabled ? .enabled(continueButtonText) : .disabled(continueButtonText))
    }

    private func setupInitialLayout() {

        addSubview(nameField)
        addSubview(lastnameField)
        addSubview(continueButton)

        nameField.snp.makeConstraints {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.height.equalTo(76) // TODO: Ivan fix InputField constraints to have min content size
        }

        lastnameField.snp.makeConstraints {
            $0.top.equalTo(nameField.snp.bottom)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.height.equalTo(76) // TODO: Ivan fix InputField constraints to have min content size
        }

        continueButton.snp.makeConstraints {
            $0.top.equalTo(lastnameField.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }
}

private extension KYCEnterNameView {
    func updateButtonState(to newState: BaseContinueButtonState) {
        state = newState
        state.apply(to: continueButton)
    }
}
