import UIKit
import SoraUIKit

final class KYCEnterPhoneView: UIView {

    var onCountry: (() -> Void)?
    var onInput: ((String) -> Void)?
    var onContinueButton: (() -> Void)?

    private var timer = Timer()
    private var secondsLeft = 0
    private var isPhoneNumberZeroPrefixCorrectionOn = true

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
            textColor: .fgInverted,
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(phoneNumber: String) {
        inputField.sora.text = phoneNumber
    }

    func configure(errorMessage: String, isContinueEnabled: Bool, secondsLeft: Int) {

        self.secondsLeft = secondsLeft
        timer.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTimer),
            userInfo: nil,
            repeats: true
        )

        switch (errorMessage.isEmpty, isContinueEnabled) {
        case (true, true):
            inputField.sora.state = .success
        case (true, false):
            inputField.sora.state = .disabled
            inputField.sora.state = .default
        case (false, true):
            inputField.sora.state = .disabled
            inputField.sora.state = .default
        case (false, false):
            inputField.sora.state = .fail
        }
        inputField.sora.descriptionLabelText = errorMessage
        continueButton.sora.isEnabled = isContinueEnabled
    }

    func configure(country: SCCountry) {
        countryView.leftImageView.image = country.flag
        countryView.titleLabel.sora.text = country.localizedName
        codeField.sora.text = country.dialCode
    }

    private func setupInitialLayout() {

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

    @objc private func updateTimer() {
        guard secondsLeft > 1 else {
            continueButton.isEnabled = true
            continueButton.sora.attributedText = SoramitsuTextItem(
                text: R.string.soraCard.commonSendCode(preferredLanguages: .currentLocale),
                fontData: FontType.buttonM,
                textColor: .bgSurface,
                alignment: .center
            )
            secondsLeft = 0
            timer.invalidate()
            return
        }
        secondsLeft -= 1
        continueButton.isEnabled = false
        continueButton.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.verifyEmailResend(
                String(secondsLeft),
                preferredLanguages: .currentLocale
            ),
            fontData: FontType.buttonM,
            textColor: .bgSurface,
            alignment: .center
        )
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
