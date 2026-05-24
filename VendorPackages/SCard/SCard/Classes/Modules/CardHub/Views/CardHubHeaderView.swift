import UIKit
import SoraUIKit

final class CardHubHeaderView: SoramitsuView {

    var onExchange: (() -> Void)?
    var onSettings: (() -> Void)?

    private let iconView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.picture = .logo(image: R.image.scFront()!)
        view.snp.makeConstraints {
            $0.width.equalTo(view.snp.height).multipliedBy(1.66)
        }
        return view
    }()

    private let cardLabelView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .custom(20)
        view.sora.backgroundColor = .bgSurface
        view.isHidden = true // TODO: impl
        return view
    }()

    private let cardLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        label.sora.text = "Show details" // TODO: localize
        return label
    }()

    private let titleLabel: SoramitsuLabel = {

        let sora = SoramitsuTextItem(
            text: "SORA ",
            fontData: FontType.textBoldL,
            textColor: .fgPrimary
        )

        let card = SoramitsuTextItem(
            text: "Card",
            fontData: FontType.textL,
            textColor: .fgPrimary
        )

        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .left
        label.sora.attributedText = [sora, card]
        return label
    }()

    private let balanceLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.sora.text = "      "
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return label
    }()

    private lazy var exchangeButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .tonal(.primary))
        button.sora.cornerRadius = .custom(28)
        button.sora.title = "Exchange XOR" //R.string.soraCard.cardHubManageCard(preferredLanguages: .currentLocale)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onExchange?()
        }
        button.isEnabled = false
        return button
    }()

    private lazy var settingsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .tonal(.primary))
        button.sora.leftImage = R.image.settings()//?.withTintColor( .primary)
        button.sora.cornerRadius = .circle
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onSettings?()
        }
        return button
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = false
        self.sora.backgroundColor = .bgSurface
        self.sora.shadow = .default
        self.sora.cornerRadius = .max
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(balance: Int?) {
        // TODO: add localization
        balanceLabel.sora.text = balance != nil ?
            BalanceConverter.formatedBalance(balance: balance!) : "--"
        balanceLabel.sora.loadingPlaceholder.type = .none
    }

    private func setupInitialLayout() {

        addSubview(iconView) {
            $0.top.leading.trailing.equalToSuperview().inset(16)
        }

        cardLabelView.addSubview(cardLabel) {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        iconView.addSubview(cardLabelView) {
            $0.trailing.bottom.equalToSuperview().inset(8)
        }

        addSubview(titleLabel) {
            $0.top.equalTo(iconView.snp.bottom).offset(16)
            $0.leading.equalToSuperview().inset(24)
        }

        addSubview(balanceLabel) {
            $0.centerY.equalTo(titleLabel)
            $0.leading.equalTo(titleLabel.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(24)
        }

        let buttonsView = SoramitsuStackView(arrangedSubviews: [
            exchangeButton,
            settingsButton
        ])
        buttonsView.spacing = 16

        settingsButton.snp.makeConstraints {
            $0.size.equalTo(56)
        }

        addSubview(buttonsView) {
            $0.top.equalTo(titleLabel.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(16)
        }
    }
}
