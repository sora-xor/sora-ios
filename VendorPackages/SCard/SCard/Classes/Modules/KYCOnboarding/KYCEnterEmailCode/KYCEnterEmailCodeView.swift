import UIKit
import SoraUIKit

final class KYCEnterEmailCodeView: UIView {

    var onResendButton: (() -> Void)?
    var onChangeEmailButton: (() -> Void)?
    var onCode: ((String) -> Void)?

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    private lazy var resendButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.title = R.string.soraCard.commonResendLink(preferredLanguages: .currentLocale).capitalized
        button.sora.cornerRadius = .custom(28)
        button.isEnabled = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onResendButton?()
        }
        return button
    }()

    private lazy var changeEmailButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .text(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.commonChangeEmail(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .accentSecondary,
            alignment: .center
        )
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onChangeEmailButton?()
        }
        return button
    }()

    private var timer = Timer()
    private var secondsLeft = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(email: String, secondsLeft: Int) {
        self.secondsLeft = secondsLeft
        textLabel.sora.text = R.string.soraCard.verifyEmailDescription(email, preferredLanguages: .currentLocale)

        timer.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTimer),
            userInfo: nil,
            repeats: true
        )
    }

    private func setupInitialLayout() {
        addSubview(textLabel)
        addSubview(resendButton)
        addSubview(changeEmailButton)

        textLabel.snp.makeConstraints {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        resendButton.snp.makeConstraints {
            $0.top.equalTo(textLabel.snp.bottom).offset(70)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        changeEmailButton.snp.makeConstraints {
            $0.top.equalTo(resendButton.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
        }
    }

    @objc private func updateTimer() {
        guard secondsLeft > 1 else {
            resendButton.isEnabled = true
            resendButton.sora.attributedText = SoramitsuTextItem(
                text: R.string.soraCard.commonResendLink(preferredLanguages: .currentLocale),
                fontData: FontType.buttonM,
                textColor: .fgInverted,
                alignment: .center
            )
            secondsLeft = 0
            timer.invalidate()
            return
        }
        secondsLeft -= 1
        resendButton.isEnabled = false
        resendButton.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.verifyEmailResend(String(secondsLeft), preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .fgInverted,
            alignment: .center
        )
    }
}
