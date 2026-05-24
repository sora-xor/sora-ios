import UIKit
import SoraUIKit

final class KYCNotRegistredView: UIView {

    var onTryAnotherNumberButton: (() -> Void)?
    var onRegisterButton: (() -> Void)?

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.soraCard.userNotFound(preferredLanguages: .currentLocale)
        return label
    }()

    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 3
        return label
    }()

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.soraCard.noNumberInDatabase(preferredLanguages: .currentLocale)
        return label
    }()

    private lazy var tryButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .tonal(.secondary))
        button.sora.title = R.string.soraCard.tryAnotherNumber(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onTryAnotherNumberButton?()
        }
        return button
    }()

    private lazy var registerButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.primary))
        button.sora.title = R.string.soraCard.registerNewAccount(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onRegisterButton?()
        }
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

    func configure(phoneNumber: String) {
        descriptionLabel.sora.text = "\(R.string.soraCard.yourPhoneNumber(preferredLanguages: .currentLocale)): \(phoneNumber)"
    }

    private func setupInitialLayout() {

        addSubview(titleLabel) {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        addSubview(descriptionLabel) {
            $0.top.equalTo(titleLabel.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        addSubview(textLabel) {
            $0.top.equalTo(descriptionLabel.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        let buttonsView = UIStackView(arrangedSubviews: [
            tryButton,
            registerButton
        ])
        buttonsView.axis = .vertical
        buttonsView.spacing = 16

        addSubview(buttonsView) {
            $0.top.greaterThanOrEqualTo(textLabel.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(self.safeAreaLayoutGuide).offset(-24)
        }
    }
}
