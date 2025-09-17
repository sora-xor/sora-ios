import UIKit
import SoraUIKit

final class KYCEnterPhoneView: UIView {

    var onCountry: (() -> Void)?
    var onInput: ((String) -> Void)?
    var onContinueButton: (() -> Void)?

    private var timer = Timer()
    private var secondsLeft = 0
    private var isPhoneNumberZeroPrefixCorrectionOn = true
    
    private var state: ContinueButtonState = ContinueButtonState.disabled

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.text = R.string.soraCard.enterPhoneNumberDescription(preferredLanguages: .currentLocale)
        return label
    }()

    private(set) lazy var codeField: InputField = {
        let view = InputField()
        view.sora.state = .default
        view.isUserInteractionEnabled = false
        return view
    }()

    private(set) lazy var inputField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.soraCard.enterPhoneNumberPhoneInputFieldLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.soraCard.enterPhoneNumberPhoneInputFieldLabel(preferredLanguages: .currentLocale)
        view.sora.descriptionLabelText = R.string.soraCard.commonNoSpam(preferredLanguages: .currentLocale)
        view.sora.keyboardType = .phonePad
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.onInput?(self?.inputField.sora.text ?? "")
        }
        return view
    }()

    private lazy var countryView: IconTitleIconView = {
        let view = IconTitleIconView()
        view.rightImageView.sora.tintColor = .fgSecondary
        view.rightImageView.sora.picture = .logo(image: R.image.arrowRightSmall() ?? .init())
        view.addTapGesture { [weak self] _ in
            self?.onCountry?()
        }
        return view
    }()

    private lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.commonSendCode(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .fgSecondary,
            alignment: .center
        )
        button.sora.isEnabled = false
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onContinueButton?()
        }
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
        configure(country: .usa)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Internal methods

extension KYCEnterPhoneView {
    func configure(phoneNumber: String) {
        inputField.sora.text = phoneNumber
    }

    func configure(country: SCCountry) {
        countryView.leftImageView.image = country.flag
        countryView.titleLabel.sora.text = country.localizedName
        codeField.sora.text = country.dialCode
    }

    // MARK: Configure TextField and Continue Button States, set timer if needed
    
    func configure(errorMessage: String, isContinueEnabled: Bool, secondsLeft: Int) {
        self.secondsLeft = secondsLeft
        resetTimerIfNeeded()
        updateInputFieldState(errorMessage: errorMessage)
        setInitialButtonState(errorMessage: errorMessage, isContinueEnabled: isContinueEnabled, secondsLeft: secondsLeft)
    }
}

// MARK: - Helper' methods

private extension KYCEnterPhoneView {
    func resetTimerIfNeeded() {
        timer.invalidate()
        
        if secondsLeft > 0 {
            timer = Timer.scheduledTimer(
                timeInterval: 1,
                target: self,
                selector: #selector(updateTimer),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    func updateInputFieldState(errorMessage: String) {
        inputField.sora.state = errorMessage.isEmpty ? .success : .fail
        inputField.sora.descriptionLabelText = errorMessage
    }
    
    func setInitialButtonState(errorMessage: String, isContinueEnabled: Bool, secondsLeft: Int) {
        let initialState: ContinueButtonState = secondsLeft > 0
        ? .disabledCount(secondsLeft: secondsLeft)
        : (isContinueEnabled ? .enabled : .disabled)
        
        updateButtonState(to: initialState)
    }
    
    func updateButtonState(to newState: ContinueButtonState) {
        state = newState
        state.apply(to: continueButton)
    }

    @objc func updateTimer() {
        guard secondsLeft > 1 else {
            secondsLeft = 0
            timer.invalidate()
            let stateAfterTimeOut: ContinueButtonState = inputField.sora.state == .fail ? .disabled : .enabled
            updateButtonState(to: stateAfterTimeOut)
            return
        }
        
        secondsLeft -= 1
        updateButtonState(to: .disabledCount(secondsLeft: secondsLeft))
    }
}


// MARK: - Layout setups

private extension KYCEnterPhoneView {
    func setupInitialLayout() {
        
        addSubview(textLabel) {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
        
        addSubview(countryView) {
            $0.top.equalTo(textLabel.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview()
        }
        
        addSubview(codeField) {
            $0.top.equalTo(countryView.snp.bottom).offset(24)
            $0.leading.equalToSuperview().inset(24)
            $0.width.equalTo(85)
        }
        
        addSubview(inputField) {
            $0.top.equalTo(countryView.snp.bottom).offset(24)
            $0.leading.equalTo(codeField.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(24)
        }
        
        addSubview(continueButton) {
            $0.top.equalTo(inputField.snp.bottom).offset(28)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }
}


extension String {
    func image(
        withAttributes attributes: [NSAttributedString.Key: Any]? = nil,
        size: CGSize? = nil
    ) -> UIImage? {
        let size = size ?? (self as NSString).size(withAttributes: attributes)
        return UIGraphicsImageRenderer(size: size).image { _ in
            (self as NSString).draw(
                in: CGRect(origin: .zero, size: size),
                withAttributes: attributes
            )
        }
    }
}

// MARK: - ContinueButtonState

enum ContinueButtonState {
    case disabledCount(secondsLeft: Int)
    case enabled
    case disabled
    
    var isEnabled: Bool {
        switch self {
        case .enabled:
            return true
        case .disabled, .disabledCount:
            return false
        }
    }
    
    var textItem: SoramitsuTextItem {
        let text: String
        let color: SoramitsuColor
        switch self {
            
        case .disabledCount(let secondsLeft):
            text = R.string.soraCard.verifyEmailResend(String(secondsLeft), preferredLanguages: .currentLocale)
            color = .fgSecondary
        case .enabled:
            text = R.string.soraCard.commonSendCode(preferredLanguages: .currentLocale)
            color = .bgSurface
        case .disabled:
            text = R.string.soraCard.commonSendCode(preferredLanguages: .currentLocale)
            color = .fgSecondary
        }
        return SoramitsuTextItem(
            text: text,
            fontData: FontType.buttonM,
            textColor: color,
            alignment: .center
        )
    }
    
    func apply(to button: SoramitsuButton) {
        button.isEnabled = self.isEnabled
        button.sora.attributedText = self.textItem
    }
}
