import UIKit
import SoraUIKit

final class ExchangeOnboardingReasonView: UIView {

    var onReason: ((ExchangeOnboarding.OpeningReason) -> Void)?
    var onContinue: (() -> Void)?

    private let title: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.soraCard.openingReason(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()

    private let subtitle: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.soraCard.selectMany(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        return label
    }()

    private let variantsStack: SoramitsuStackView = {
        let view = SoramitsuStackView()
        view.axis = .vertical
        view.spacing = 8
        return view
    }()

    private lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.commonNext(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .bgSurface,
            alignment: .center
        )
        button.sora.cornerRadius = .custom(28)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.continueButton.sora.isEnabled = false
            self?.onContinue?()
            self?.continueButton.sora.isEnabled = true
        }
        button.sora.isEnabled = false
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

    func configure(
        variants: [ExchangeOnboarding.OpeningReason: Bool]
    ) {

        variantsStack.removeArrangedSubviews()

        var hasSelectedVariant = false
        for variant in variants.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let checkBoxView = CheckBoxView(title: variant.key.title)
            checkBoxView.isSelected = variant.value
            checkBoxView.addTapGesture { [weak self] _ in
                self?.onReason?(variant.key)
            }
            variantsStack.addArrangedSubview(checkBoxView)
            hasSelectedVariant = hasSelectedVariant || variant.value
        }

        continueButton.sora.isEnabled = hasSelectedVariant
    }

    private func setupInitialLayout() {

        self.clipsToBounds = false
        self.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)

        let contentView = UIView()
        contentView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgSurface)
        contentView.layer.cornerRadius = 32

        addSubview(contentView) {
            $0.top.equalTo(self.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(variantsStack)
        contentView.addSubview(continueButton)

        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(24)
        }

        subtitle.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        variantsStack.snp.makeConstraints {
            $0.top.equalTo(subtitle.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        continueButton.snp.makeConstraints {
            $0.top.equalTo(variantsStack.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview().inset(24)
        }
    }
}

extension ExchangeOnboarding.OpeningReason {
    var title: String {
        switch self {
        case .trading:
            R.string.soraCard.itemTrading(preferredLanguages: .currentLocale)
        case .sending:
            R.string.soraCard.itemSendingReceivingCrypto(preferredLanguages: .currentLocale)
        case .purchasing:
            R.string.soraCard.itemPurchasingCrypto(preferredLanguages: .currentLocale)
        case .holding:
            R.string.soraCard.itemHoldingCrypto(preferredLanguages: .currentLocale)
        case .mining:
            R.string.soraCard.itemReceivingMiningProfits(preferredLanguages: .currentLocale)            
        }
    }
}
