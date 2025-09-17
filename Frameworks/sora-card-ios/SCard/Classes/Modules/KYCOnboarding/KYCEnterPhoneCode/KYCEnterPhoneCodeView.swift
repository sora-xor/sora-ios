import UIKit
import SoraUIKit

final class KYCEnterPhoneCodeView: UIView {

    var onResendButton: (() -> Void)?
    var onCode: ((String) -> Void)?

    private var timer = Timer()
    private var secondsLeft = 0

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    private(set) lazy var inputField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.soraCard.verifyPhoneNumberCodeInputFieldLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.soraCard.verifyPhoneNumberCodeInputFieldLabel(preferredLanguages: .currentLocale)
        view.sora.keyboardType = .numberPad
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.onCode?(self?.inputField.sora.text ?? "")
        }
        return view
    }()

    private lazy var resendButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.verifyEmailResend("...", preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .fgSecondary,
            alignment: .center
        )
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onResendButton?()
        }
        button.isEnabled = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(phoneNumber: String, secondsLeft: Int, codeState: KYCPhoneCodeState) {
        textLabel.sora.text =  R.string.soraCard.verifyPhoneNumberDescription(phoneNumber, preferredLanguages: .currentLocale)
        self.secondsLeft = secondsLeft

        timer.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTimer),
            userInfo: nil,
            repeats: true
        )

        switch codeState {
        case .succeed:
            inputField.sora.state = .success
            inputField.sora.descriptionLabelText = "Succeed" // TODO: SC localize
        case .editing:
            inputField.sora.state = .default // TODO: not working after success state
            inputField.sora.descriptionLabelText = ""
        case .sent:
            inputField.sora.state = .disabled
            inputField.sora.descriptionLabelText = "Cheking..." // TODO: SC localize
        case let .wrong(error):
            inputField.sora.state = .fail
            inputField.sora.descriptionLabelText = error
        }
    }

    private func setupInitialLayout() {
        addSubview(textLabel)
        addSubview(inputField)
        addSubview(resendButton)

        textLabel.snp.makeConstraints {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        inputField.snp.makeConstraints {
            $0.top.equalTo(textLabel.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.height.equalTo(76) // TODO: Ivan fix InputField constraints to have min content size
        }

        resendButton.snp.makeConstraints {
            $0.top.equalTo(inputField.snp.bottom).offset(28)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }

    @objc private func updateTimer() {
        guard secondsLeft > 1 else {
            resendButton.isEnabled = true
            resendButton.sora.attributedText = SoramitsuTextItem(
                text: R.string.soraCard.verifyPhoneNumberSendCode(preferredLanguages: .currentLocale),
                fontData: FontType.buttonM,
                textColor: .bgSurface,
                alignment: .center
            )
            secondsLeft = 0
            timer.invalidate()
            return
        }
        secondsLeft -= 1
        resendButton.isEnabled = false
        resendButton.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.verifyEmailResend(
                String(secondsLeft),
                preferredLanguages: .currentLocale
            ),
            fontData: FontType.buttonM,
            textColor: .fgSecondary,
            alignment: .center
        )
    }
}
