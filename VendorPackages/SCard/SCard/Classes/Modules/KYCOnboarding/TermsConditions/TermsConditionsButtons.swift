import UIKit
import SoraUIKit

final class TermsConditionsButtons: SoramitsuView {

    var onGeneralTerms: (() -> Void)?
    var onPrivacy: (() -> Void)?

    private var containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .small
        view.spacing = 23
        view.sora.cornerRadius = .medium
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    lazy var generalTermsButton: TermsConditionsButton = {
        let button = TermsConditionsButton()
        button.titleLable.sora.text = R.string.soraCard.termsAndConditionsGeneralTerms(preferredLanguages: .currentLocale)
        button.addTarget(self, action: #selector(onGeneralTermsTap), for: .touchUpInside)
        return button
    }()

    lazy var privacyButton: TermsConditionsButton = {
        let button = TermsConditionsButton()
        button.titleLable.sora.text = R.string.soraCard.termsAndConditionsPrivacyPolicy(preferredLanguages: .currentLocale)
        button.addTarget(self, action: #selector(onPrivacyTap), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        sora.shadow = .default
        sora.cornerRadius = .small
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {

        addSubview(containerView)

        containerView.addArrangedSubviews([
            generalTermsButton,
            privacyButton

        ])

        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    @objc private func onGeneralTermsTap() {
        onGeneralTerms?()
    }

    @objc private func onPrivacyTap() {
        onPrivacy?()
    }
}

final class TermsConditionsButton: UIControl {
    let titleLable: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let iconImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.transform = CGAffineTransform(rotationAngle: -.pi/2)
        view.sora.picture = .icon(image: R.image.arrowDown()!, color: .fgSecondary)
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLable)
        titleLable.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }

        addSubview(iconImageView)
        iconImageView.snp.makeConstraints {
            $0.leading.equalTo(titleLable.snp.trailing).offset(8)
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.height.equalTo(14)
            $0.width.equalTo(9)
        }
    }
}
