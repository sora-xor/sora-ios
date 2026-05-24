import SoraUIKit
import SnapKit

public final class SCCardCell: SoramitsuTableViewCell {

    var onClose: (() -> Void)?
    var onCard: (() -> Void)?

    private lazy var bgImage: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.picture = .logo(image: R.image.scFront()!)
        view.sora.isUserInteractionEnabled = true
        view.sora.cornerRadius = .medium
        view.sora.clipsToBounds = true
        view.addTapGesture { [unowned self] _ in
            self.onCard?()
        }
        return view
    }()

    private lazy var bgImageTintView: SoramitsuView = {
        let view = SoramitsuView()
        let color = SoramitsuUI.shared.theme.palette.color(.bgPage).withAlphaComponent(0.8)
        view.sora.backgroundColor = .custom(uiColor: color)
        view.sora.isHidden = true
        return view
    }()

    private lazy var closeButton: ImageButton = {
        let button = ImageButton(size: .init(width: 32, height: 32))
        button.setImage(R.image.close(), for: .normal)
        button.sora.addHandler(for: .touchUpInside) { [unowned self] in
            self.onClose?()
        }
        button.sora.backgroundColor = .bgSurface
        button.sora.cornerRadius = .circle
        return button
    }()

    private lazy var getCardContainer: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .custom(28)
        view.sora.backgroundColor = .bgPage
        view.sora.isHidden = true
        return view
    }()

    private lazy var updateAppLabel: SoramitsuLabel = {
        let view = SoramitsuLabel()
        view.sora.textColor = .fgPrimary
        view.sora.font = FontType.headline2
        view.sora.alignment = .center
        view.sora.numberOfLines = 0
        view.adjustsFontSizeToFitWidth = true
        view.minimumScaleFactor = 0.2
        view.sora.text = R.string.soraCard.cardUpdateTitle(preferredLanguages: .currentLocale)
        return view
    }()

    private lazy var getCardLabel: SoramitsuLabel = {
        let view = SoramitsuLabel()
        view.sora.text = KYCUserStatus.notStarted.text
        view.sora.textColor = .fgPrimary
        view.sora.alignment = .center
        view.sora.isHidden = true
        return view
    }()

    private lazy var cardInfoContainer: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .circle
        view.sora.backgroundColor = .custom(uiColor: .white) // TODO: design waiting
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()

    private lazy var cardInfoLabel: SoramitsuLabel = {
        let view = SoramitsuLabel()
        view.sora.text = R.string.soraCard.entryCardInfo(preferredLanguages: .currentLocale)
        view.sora.textColor = .custom(uiColor: .black)
        view.sora.alignment = .center
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupConstraints()

        let localizableTitle = { (locale: Locale) in
            R.string.soraCard.statusNotStarted(preferredLanguages: locale.rLanguages)
        }

        LocalizationManager.shared.addObserver(with: getCardLabel) { [weak getCardLabel] (_, _) in
            let currentTitle = localizableTitle(LocalizationManager.shared.selectedLocale)
            getCardLabel?.sora.text = currentTitle
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let ratio = bgImage.image!.size.height / bgImage.image!.size.width
        contentView.addSubview(bgImage) {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.bottom.equalToSuperview().inset(8)
            $0.height.equalTo(bgImage.snp.width).multipliedBy(ratio).priority(990)
        }

        bgImage.addSubview(bgImageTintView) {
            $0.edges.equalToSuperview()
        }

        bgImage.addSubview(closeButton) {
            $0.top.trailing.equalToSuperview().inset(10)
        }

        getCardLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        getCardContainer.addSubview(getCardLabel) {
            $0.top.bottom.equalToSuperview().inset(20)
            $0.leading.trailing.equalToSuperview().inset(30)
        }

        bgImage.addSubview(getCardContainer) {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(24)
            $0.width.lessThanOrEqualToSuperview().multipliedBy(0.90)
        }

        bgImageTintView.addSubview(updateAppLabel) {
            $0.top.greaterThanOrEqualToSuperview().inset(16)
            $0.bottom.equalTo(getCardContainer.snp.top).offset(-16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        cardInfoContainer.addSubview(cardInfoLabel) {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        bgImage.addSubview(cardInfoContainer) {
            $0.bottom.trailing.equalToSuperview().inset(8)
        }
    }
}

extension SCCardCell: SoramitsuTableViewCellProtocol {
    public func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SCCardItem else { return }
        sora.backgroundColor = .custom(uiColor: .clear)
        self.onClose = item.onClose
        self.onCard = item.onCard

        item.onUpdate = { [weak self] status, availableBalance in
            self?.update(status: status, availableBalance: availableBalance, needUpdate: item.needUpdate)
        }
        self.update(status: item.userStatus, availableBalance: item.availableBalance, needUpdate: item.needUpdate)
    }

    private func update(status: KYCUserStatus, availableBalance: Int?, needUpdate: Bool) {

        guard status != .none else { return }

        getCardLabel.sora.isHidden = false

        guard !needUpdate else {
            bgImageTintView.sora.isHidden = false
            closeButton.isHidden = false
            cardInfoContainer.sora.isHidden = true
            getCardContainer.isHidden = false
            cardInfoContainer.sora.loadingPlaceholder.type = .none
            getCardLabel.sora.text = R.string.soraCard.cardUpdateButton(preferredLanguages: .currentLocale)
            getCardLabel.sora.textColor = .bgSurface
            getCardContainer.sora.backgroundColor = .accentSecondary
            return
        }

        bgImageTintView.sora.isHidden = true
        closeButton.isHidden = status == .successful
        getCardContainer.isHidden = status == .successful
        cardInfoContainer.sora.isHidden = status != .successful
        getCardLabel.sora.text = status.text
        getCardLabel.sora.textColor = (status == .notStarted || status == .userCanceled) ? .bgSurface : .accentTertiary
        getCardContainer.sora.backgroundColor = (status == .notStarted || status == .userCanceled) ? .accentSecondary : .accentTertiaryContainer

        if status == .successful {
            if  let availableBalance = availableBalance {
                cardInfoLabel.sora.text = BalanceConverter.formatedBalance(balance: availableBalance)
                cardInfoContainer.sora.loadingPlaceholder.type = .none
            } else {
                cardInfoLabel.sora.text = R.string.soraCard.entryCardInfo(preferredLanguages: .currentLocale)
            }
        }
        cardInfoContainer.sora.loadingPlaceholder.type = .none
    }
}

public extension KYCUserStatus {

    var text: String {
        switch self {
        case .notStarted, .userCanceled, .none: // TODO: use See the details
            return R.string.soraCard.statusNotStarted(preferredLanguages: .currentLocale)
        case .pending:
            return R.string.soraCard.kycResultVerificationInProgress(preferredLanguages: .currentLocale)
        case .rejected:
            return R.string.soraCard.verificationRejectedTitle(preferredLanguages: .currentLocale)
        case .successful:
            return R.string.soraCard.verificationSuccessfulTitle(preferredLanguages: .currentLocale)
        }
    }
}
