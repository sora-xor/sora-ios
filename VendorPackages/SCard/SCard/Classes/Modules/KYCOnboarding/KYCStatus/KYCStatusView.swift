import UIKit
import SoraUIKit

final class KYCStatusView: UIView {

    var onLogoutButton: (() -> Void)?
    var onRetryButton: (() -> Void)?
    var onSupportButton: (() -> Void)?

    private lazy var logoutButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .text(.primary))
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onLogoutButton?()
        }
        button.sora.title = R.string.soraCard.logOut(preferredLanguages: .currentLocale)
        return button
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let phoneLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 3
        return label
    }()

    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 3
        return label
    }()

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private let iconView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.contentMode = .scaleAspectFit
        return view
    }()

    private let actionDescriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    private lazy var actionButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.verificationRejectedScreenTryAgainForFree(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .bgSurface,
            alignment: .center
        )
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onRetryButton?()
        }
        button.sora.cornerRadius = .custom(28)
        button.sora.isHidden = true
        return button
    }()

    private lazy var supportButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .tonal(.secondary))
        button.sora.cornerRadius = .custom(28)
        button.sora.title = R.string.soraCard.verificationRejectedSupport(preferredLanguages: .currentLocale)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onSupportButton?()
        }
        return button
    }()

    private let activityIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
        activityIndicatorView.startAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(phoneNumber: String) {
        phoneLabel.sora.text = "\(R.string.soraCard.yourPhoneNumber(preferredLanguages: .currentLocale)): \(phoneNumber)"
    }

    func configure(error: String) {
        activityIndicatorView.stopAnimating()
        titleLabel.sora.text = R.string.soraCard.commonErrorGeneralTitle(preferredLanguages: .currentLocale)
        descriptionLabel.sora.text = "\(error)"
        actionButton.sora.title = R.string.soraCard.commonTryAgain(preferredLanguages: .currentLocale)
        actionButton.sora.removeAllHandlers(for: .touchUpInside)
        actionButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onRetryButton?()
        }
        iconView.sora.picture = .logo(image: R.image.kycRejected()!)
    }

    func configure(state: KYCUserStatus, freeAttemptsLeft: Int, retryFee: String) {
        activityIndicatorView.stopAnimating()
        switch state {
        case .pending:
            titleLabel.sora.text = R.string.soraCard.kycResultVerificationInProgress(preferredLanguages: .currentLocale)
            descriptionLabel.sora.text = R.string.soraCard.kycResultVerificationInProgressDescription(preferredLanguages: .currentLocale)
            iconView.sora.picture = .logo(image: R.image.kycPending()!)
            actionButton.sora.isHidden = true

        case .successful:
            titleLabel.sora.text = R.string.soraCard.verificationSuccessfulTitle(preferredLanguages: .currentLocale)
            descriptionLabel.sora.text = R.string.soraCard.verificationSuccessfulDescription(preferredLanguages: .currentLocale)
            iconView.sora.picture = .logo(image: R.image.kycSuccessful()!)
            actionButton.sora.isHidden = true

        case .notStarted, .userCanceled, .none:
            titleLabel.sora.text = R.string.soraCard.verificationFailedTitle(preferredLanguages: .currentLocale)
            descriptionLabel.sora.text = R.string.soraCard.verificationFailedDescription(preferredLanguages: .currentLocale)
            iconView.sora.picture = .logo(image: R.image.kycRejected()!)

            actionButton.sora.isHidden = false
            actionButton.sora.type = .filled(.secondary)
            actionButton.sora.title = R.string.soraCard.commonTryAgain(preferredLanguages: .currentLocale)

        case .rejected(let rejection):

            titleLabel.sora.text = R.string.soraCard.verificationRejectedTitle(preferredLanguages: .currentLocale)
            descriptionLabel.sora.text = rejection.additionalDescription ?? R.string.soraCard.verificationRejectedDescription(preferredLanguages: .currentLocale)

            textLabel.sora.text = rejection.reasons.map { "• \($0)" }.joined(separator: "\n")

            iconView.sora.picture = .logo(image: R.image.kycRejected()!)

            actionButton.sora.isHidden = false

            if freeAttemptsLeft > 0 {

                let text = R.string.soraCard.verificationRejectedScreenAttemptsLeft(
                    format: freeAttemptsLeft,
                    preferredLanguages: .currentLocale
                )

                let attemptsLeft = SoramitsuTextItem(
                    text:  text,
                    fontData: ScreenSizeMapper.value(small: FontType.paragraphBoldS, medium: FontType.paragraphBoldM, large: FontType.paragraphBoldM),
                    textColor: .fgPrimary,
                    alignment: .center
                )
                actionDescriptionLabel.sora.attributedText =  [attemptsLeft]
                actionButton.sora.title = R.string.soraCard.verificationRejectedScreenTryAgainForFree(preferredLanguages: .currentLocale)

                // TODO: impl in phase 2
                actionButton.isHidden = false

            } else {
                let attemptsLeft = SoramitsuTextItem(
                    text:  R.string.soraCard.verificationRejectedScreenAttemptsUsed(preferredLanguages: .currentLocale),
                    fontData: ScreenSizeMapper.value(small: FontType.paragraphBoldS, medium: FontType.paragraphBoldM, large: FontType.paragraphBoldM),
                    textColor: .fgPrimary,
                    alignment: .center
                )
                let paidAttemptsAvailableLater = SoramitsuTextItem(
                    text: "\n" + R.string.soraCard.paidAttemptsAvailableLater(preferredLanguages: .currentLocale),
                    fontData: ScreenSizeMapper.value(small: FontType.paragraphS, medium: FontType.paragraphM, large: FontType.paragraphM),
                    textColor: .fgPrimary,
                    alignment: .center
                )
                actionDescriptionLabel.sora.attributedText =  [attemptsLeft, paidAttemptsAvailableLater]
                actionButton.sora.title = R.string.soraCard.verificationRejectedScreenTryAgainForEuros(String(retryFee), preferredLanguages: .currentLocale)

                // TODO: impl in phase 2
                actionButton.isHidden = true
            }
        }
    }

    private func setupInitialLayout() {

        addSubview(titleLabel)
        addSubview(phoneLabel)
        addSubview(descriptionLabel)

        let textScrollView = UIScrollView()
        textScrollView.addSubview(textLabel)
        textScrollView.addSubview(iconView)
        addSubview(textScrollView)

        let buttonsView = UIStackView(arrangedSubviews: [
            actionDescriptionLabel,
            actionButton,
            supportButton,
            logoutButton
        ])
        buttonsView.axis = .vertical
        buttonsView.spacing = 16

        addSubview(buttonsView) {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(self.safeAreaLayoutGuide).offset(-24)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        phoneLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(phoneLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        textScrollView.snp.makeConstraints {
            $0.top.equalTo(descriptionLabel.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(buttonsView.snp.top).offset(-16)
        }

        textLabel.snp.makeConstraints {
            $0.top.equalTo(textScrollView)
            $0.leading.trailing.equalTo(self).inset(24)
        }

        iconView.snp.makeConstraints {
            $0.top.equalTo(textLabel.snp.bottom).offset(16)
            $0.centerX.equalTo(self)
            $0.size.equalTo(self.snp.width).multipliedBy(0.7)
            $0.bottom.equalTo(textScrollView).offset(16)
        }

        addSubview(activityIndicatorView) {
            $0.center.equalToSuperview()
        }
    }
}
