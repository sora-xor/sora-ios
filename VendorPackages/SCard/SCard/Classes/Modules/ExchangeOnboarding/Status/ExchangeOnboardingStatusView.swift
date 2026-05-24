import UIKit
import SwiftUI
import SoraUIKit
import Rswift

final class ExchangeOnboardingStatusView: UIView {

    struct Data {
        let icon: UIImage
        let title: String
        let subtitle: String
        let withSupportButton: Bool

        static let pending: Data = .init(
            icon: R.image.timeIcon()!,
            title: R.string.soraCard.almostThere(preferredLanguages: .currentLocale),
            subtitle: R.string.soraCard.gatehubOnboardingDescription(preferredLanguages: .currentLocale),
            withSupportButton: false
        )

        static func error(message: String) -> Data {
            .init(
                icon: R.image.rejectionIcon()!,
                title: R.string.soraCard.errorOccured(preferredLanguages: .currentLocale),
                subtitle: message,
                withSupportButton: true
            )
        }
    }

    var onCloseButton: (() -> Void)?
    var onSupportButton: (() -> Void)?

    private let icon: SoramitsuImageView = {
        let label = SoramitsuImageView()
        label.sora.picture = .logo(image: R.image.timeIcon()!)
        return label
    }()

    private let title: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = . center
        label.sora.numberOfLines = 0
        return label
    }()

    private let subtitle: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.sora.alignment = . center
        label.sora.numberOfLines = 0
        return label
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

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(data: Data) {
        self.icon.sora.picture = .logo(image: data.icon)
        self.title.sora.text = data.title
        self.subtitle.sora.text = data.subtitle
        supportButton.sora.isHidden = !data.withSupportButton
    }

    private func setupInitialLayout() {

        self.clipsToBounds = false
        self.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)

        let buttonsStack = UIStackView(arrangedSubviews: [
            supportButton
        ])
        buttonsStack.axis = .vertical

        let contentView = UIView()
        contentView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgSurface)
        contentView.layer.cornerRadius = 32
        contentView.addSubview(icon)
        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(buttonsStack)

        addSubview(contentView) {
            $0.top.equalTo(self.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        icon.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(24)
        }

        title.snp.makeConstraints {
            $0.top.equalTo(icon.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        subtitle.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        buttonsStack.snp.makeConstraints {
            $0.top.equalTo(subtitle.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview().inset(24)
        }
    }
}
