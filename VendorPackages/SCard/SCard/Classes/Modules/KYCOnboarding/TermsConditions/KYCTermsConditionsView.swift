import UIKit
import SoraUIKit

final class KYCTermsConditionsView: UIView {

    var onAcceptButton: (() -> Void)?
    var onBlacklistedCountriesButton: (() -> Void)?

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.soraCard.termsAndConditionsTitle(preferredLanguages: .currentLocale)
        return label
    }()

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.soraCard.termsAndConditionsDescription(preferredLanguages: .currentLocale)
        return label
    }()

    private let warningLabel: SoramitsuView = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldM
        label.sora.textColor = .accentTertiary
        label.sora.numberOfLines = 0
        label.textAlignment = .center
        label.sora.text = R.string.soraCard.termsAndConditionsSoraCommunityAlert(preferredLanguages: .currentLocale)
        // TODO: fix SoramitsuLabel contentInsets
        // label.sora.contentInsets = .init(all:  16)
        // label.sora.backgroundColor = .accentTertiaryContainer
        // label.sora.cornerRadius = .small

        let warningContainerView = SoramitsuView()
        warningContainerView.sora.backgroundColor = .accentTertiaryContainer
        warningContainerView.sora.cornerRadius = .medium
        warningContainerView.addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(16)
        }

        return warningContainerView
    }()

    lazy var termsConditionsButtons: TermsConditionsButtons = {
        let view = TermsConditionsButtons(frame: .zero)
        return view
    }()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        return view
    }()

    private let stackView: SoramitsuStackView = {
        let view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.layoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 32, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 32
        return view
    }()

    private lazy var acceptDesriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.soraCard.termsAndConditionsConfirmDescription(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        return label
    }()

    private lazy var acceptButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.termsAndConditionsAcceptAndContinue(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .bgSurface,
            alignment: .center
        )
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onAcceptButton?()
        }
        button.sora.cornerRadius = .custom(28)

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

    private func setupInitialLayout() {

        addSubview(titleLabel)
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        addSubview(acceptDesriptionLabel)
        addSubview(acceptButton)

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        stackView.addArrangedSubviews([
            textLabel,
            warningLabel,
            termsConditionsButtons
        ])

        scrollView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(16)
            $0.bottom.equalTo(acceptDesriptionLabel.snp.top).offset(-24)
            $0.leading.trailing.equalToSuperview()
        }

        stackView.snp.makeConstraints {
            $0.leading.trailing.equalTo(self)
            $0.top.bottom.equalToSuperview()
        }

        acceptDesriptionLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(acceptButton.snp.top).offset(-16)
        }

        acceptButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(self.safeAreaLayoutGuide).offset(-24)
        }
    }
}
